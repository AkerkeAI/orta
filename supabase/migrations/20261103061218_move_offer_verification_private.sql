create or replace function private.verify_unconditional_offer(p_application_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.applications%rowtype;
begin
  if private.current_role() <> 'founder' then
    raise exception 'Founder access required.';
  end if;
  select * into target
  from public.applications a
  where a.id = p_application_id
  for update;
  if not found or target.status <> 'unconditional_offer' then
    raise exception 'Only an unconditional offer can be verified.';
  end if;
  if target.unconditional_offer_verified then
    return;
  end if;
  update public.applications
  set unconditional_offer_verified = true,
      verified_by = (select auth.uid()),
      verified_at = now(),
      updated_at = now()
  where id = p_application_id;

  insert into public.payments(student_id, payment_kind, amount_kzt, status, description, related_service_id, recorded_by)
  values (target.student_id, 'remaining', 180000, 'pending',
          'Remaining payment activated after verified unconditional offer.',
          target.id, (select auth.uid()))
  on conflict (student_id, related_service_id) where payment_kind = 'remaining' do nothing;
end;
$$;
revoke all on function private.verify_unconditional_offer(uuid) from public, anon;
grant execute on function private.verify_unconditional_offer(uuid) to authenticated;

create or replace function public.verify_unconditional_offer(p_application_id uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.verify_unconditional_offer(p_application_id)
$$;
revoke all on function public.verify_unconditional_offer(uuid) from public, anon;
grant execute on function public.verify_unconditional_offer(uuid) to authenticated;
;
