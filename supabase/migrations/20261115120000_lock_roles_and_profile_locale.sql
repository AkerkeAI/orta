-- Role is assigned only by trusted provisioning and invite-trigger workflows.
-- Never derive Founder from user-editable auth metadata.
alter table public.profiles
  add column if not exists interface_language text not null default 'en';

alter table public.profiles
  add constraint profiles_interface_language_check
  check (interface_language in ('en', 'ru', 'kk'));

alter table public.registration_invites
  alter column created_by drop not null;
alter table public.registration_invites
  drop constraint if exists registration_invites_role_check;
alter table public.registration_invites
  add constraint registration_invites_role_check
  check (role in ('founder', 'student', 'mentor', 'parent'));

-- Earlier migrations re-granted table-level UPDATE after column-level grants.
-- Revoke it explicitly; authenticated clients can update only these columns.
revoke update on public.profiles from public, anon, authenticated;
revoke update (role) on public.profiles from authenticated;
grant update (full_name, phone, interface_language) on public.profiles to authenticated;

drop trigger if exists profiles_protect_role on public.profiles;
create or replace function private.protect_profile_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'Profile role can only be changed by trusted provisioning.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.protect_profile_role() from public, anon, authenticated;
create trigger profiles_protect_role
before update on public.profiles
for each row execute function private.protect_profile_role();

-- Authenticated sign-up metadata is user-controlled and cannot bootstrap Founder.
create or replace function private.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  assigned_role public.orta_role;
  invite_code uuid;
  invite_id uuid;
begin
  begin
    invite_code := (new.raw_user_meta_data ->> 'invite_code')::uuid;
  exception when others then
    invite_code := null;
  end;
  if invite_code is not null then
    select i.id, i.role into invite_id, assigned_role
    from public.registration_invites i
    where i.code = invite_code and i.used_at is null and i.expires_at > now()
      and (i.email is null or lower(i.email) = lower(new.email))
    for update;
  end if;
  if assigned_role is null then
    raise exception 'A valid ORTA invitation is required.';
  end if;
  update public.registration_invites set used_at = now(), used_by = new.id where id = invite_id;

  insert into public.profiles(id, role, full_name, interface_language)
  values (
    new.id,
    assigned_role,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    case when new.raw_user_meta_data ->> 'interface_language' in ('en', 'ru', 'kk')
      then new.raw_user_meta_data ->> 'interface_language' else 'en' end
  );
  if assigned_role = 'student' then
    insert into public.students(id) values (new.id);
  elsif assigned_role = 'mentor' then
    insert into public.mentors(id) values (new.id);
  elsif assigned_role = 'parent' then
    insert into public.parents(id) values (new.id);
  end if;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
