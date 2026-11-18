alter table public.registration_invites
  alter column created_by drop not null;
alter table public.registration_invites
  drop constraint registration_invites_role_check;
alter table public.registration_invites
  add constraint registration_invites_role_check
  check (role in ('founder', 'student', 'mentor', 'parent'));
;
