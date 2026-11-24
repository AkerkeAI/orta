-- Personal accounts self-register as students with Personal mode. Academy
-- accounts still require a valid invitation; role is never read from metadata.
alter table public.profiles drop constraint if exists profiles_id_fkey;
alter table public.profiles add constraint profiles_id_fkey
  foreign key (id) references auth.users(id) on delete cascade;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  assigned_role public.orta_role;
  invite_code uuid;
  invite_id uuid;
  requested_mode text := new.raw_user_meta_data ->> 'app_mode';
begin
  if requested_mode = 'personal' then
    assigned_role := 'student';
  else
    begin invite_code := (new.raw_user_meta_data ->> 'invite_code')::uuid;
    exception when others then invite_code := null; end;
    if invite_code is not null then
      select i.id, i.role into invite_id, assigned_role
      from public.registration_invites i
      where i.code = invite_code and i.used_at is null and i.expires_at > now()
        and (i.email is null or lower(i.email) = lower(new.email))
      for update;
    end if;
    if assigned_role is null then raise exception 'A valid ORTA invitation is required.'; end if;
    update public.registration_invites set used_at = now(), used_by = new.id where id = invite_id;
  end if;
  insert into public.profiles(id, role, full_name, interface_language, app_mode)
  values (new.id, assigned_role, coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case when new.raw_user_meta_data ->> 'interface_language' in ('en','ru','kk')
      then new.raw_user_meta_data ->> 'interface_language' else 'en' end,
    case when requested_mode = 'personal' then 'personal' else null end);
  if assigned_role = 'student' then insert into public.students(id) values (new.id);
  elsif assigned_role = 'mentor' then insert into public.mentors(id) values (new.id);
  elsif assigned_role = 'parent' then insert into public.parents(id) values (new.id); end if;
  return new;
end $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
