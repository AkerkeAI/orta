-- Keep protected identity and offer-verification fields out of direct client updates.
revoke update on public.profiles from authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

revoke insert, update on public.applications from authenticated;
grant insert (student_id, university_id, major, status, deadline, submitted_at, decision_received_at, decision_note, documents)
  on public.applications to authenticated;
grant update (major, status, deadline, submitted_at, decision_received_at, decision_note, documents)
  on public.applications to authenticated;

revoke insert, update on public.refund_requests from authenticated;
grant insert (student_id, guardian_id, reason) on public.refund_requests to authenticated;
grant update (status, amount_paid_kzt, delivered_service_value_kzt, calculated_refund_kzt, decision_note, reviewed_by, reviewed_at, processed_at)
  on public.refund_requests to authenticated;

revoke update on public.lessons from authenticated;
grant update (status, completed_at, mentor_notes) on public.lessons to authenticated;

revoke update on public.student_opportunities from authenticated;
grant update (status, student_note) on public.student_opportunities to authenticated;

revoke update on public.tasks from authenticated;
grant update (completed_at) on public.tasks to authenticated;

revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

create unique index payments_remaining_once_idx
on public.payments(student_id, related_service_id)
where payment_kind = 'remaining';

create or replace function public.verify_unconditional_offer(p_application_id uuid)
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
revoke all on function public.verify_unconditional_offer(uuid) from public, anon;
grant execute on function public.verify_unconditional_offer(uuid) to authenticated;
;
