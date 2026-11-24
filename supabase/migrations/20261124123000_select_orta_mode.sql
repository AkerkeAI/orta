-- Allow an authenticated student to save their first product mode without
-- granting broad UPDATE access to profiles.
create or replace function public.select_orta_mode(p_mode text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_mode not in ('personal', 'academy') then raise exception 'Invalid ORTA mode'; end if;
  update public.profiles set app_mode = p_mode, updated_at = now()
    where id = auth.uid() and role = 'student';
  if not found then raise exception 'Student profile required'; end if;
end $$;
revoke all on function public.select_orta_mode(text) from public;
grant execute on function public.select_orta_mode(text) to authenticated;
