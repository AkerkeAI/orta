create extension if not exists pgcrypto;

create type public.orta_role as enum ('founder', 'student', 'mentor', 'parent');
create type public.program_type as enum ('standard', 'intensive');
create type public.application_status as enum ('not_started', 'in_preparation', 'submitted', 'under_review', 'conditional_offer', 'unconditional_offer', 'rejected', 'waitlisted', 'withdrawn');
create type public.lesson_status as enum ('scheduled', 'conducted', 'confirmed', 'disputed');
create type public.refund_status as enum ('requested', 'under_review', 'approved', 'rejected', 'processed');
create type public.opportunity_status as enum ('saved', 'recommended', 'interested', 'applied', 'not_interested');

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id),
  role public.orta_role not null default 'student',
  full_name text not null default '',
  phone text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.profiles is 'ORTA app roles are assigned by trusted database/admin workflows, never by user-editable metadata.';

create table public.students (
  id uuid primary key references public.profiles(id),
  grade smallint check (grade between 9 and 12),
  countries text[] not null default '{}',
  intended_majors text[] not null default '{}',
  english_level text not null default '',
  exams jsonb not null default '{}',
  academic_summary text not null default '',
  admissions_timeline date,
  profile_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.parents (
  id uuid primary key references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.student_guardians (
  student_id uuid not null references public.students(id),
  guardian_id uuid not null references public.parents(id),
  relationship text not null default 'parent',
  contracting_party boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (student_id, guardian_id)
);
create index student_guardians_guardian_idx on public.student_guardians(guardian_id);

create table public.mentors (
  id uuid primary key references public.profiles(id),
  specializations text[] not null default '{}',
  compensation_per_lesson_kzt integer not null default 5000 check (compensation_per_lesson_kzt >= 0),
  availability jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.student_mentors (
  student_id uuid not null references public.students(id),
  mentor_id uuid not null references public.mentors(id),
  assigned_by uuid not null references public.profiles(id),
  specialization text not null,
  assigned_at timestamptz not null default now(),
  primary key (student_id, mentor_id, specialization)
);
create index student_mentors_mentor_idx on public.student_mentors(mentor_id);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  program public.program_type not null,
  price_kzt integer not null default 200000 check (price_kzt = 200000),
  initial_payment_kzt integer not null default 20000 check (initial_payment_kzt = 20000),
  remaining_payment_kzt integer not null default 180000 check (remaining_payment_kzt = 180000),
  start_date date not null,
  consultation_end_date date not null,
  planned_expert_consultations smallint not null check (planned_expert_consultations between 0 and 18),
  agreed_founder_slots smallint not null default 0 check (agreed_founder_slots between 0 and 18),
  founder_scope text not null default '',
  approved_university_ids uuid[] not null default '{}',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (consultation_end_date >= start_date),
  check (program <> 'standard' or (planned_expert_consultations = 18 and agreed_founder_slots = 0)),
  check (program <> 'intensive' or agreed_founder_slots = 18 - planned_expert_consultations)
);
create index enrollments_student_idx on public.enrollments(student_id, created_at desc);

create table public.universities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text not null,
  official_url text not null,
  programs text[] not null default '{}',
  requirements jsonb not null default '{}',
  tuition_kzt integer,
  scholarship_info text not null default '',
  source_verified_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  university_id uuid not null references public.universities(id),
  major text not null default '',
  status public.application_status not null default 'not_started',
  deadline date,
  submitted_at timestamptz,
  decision_received_at timestamptz,
  decision_note text not null default '',
  documents jsonb not null default '{}',
  unconditional_offer_verified boolean not null default false,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(student_id, university_id),
  check (not unconditional_offer_verified or (status = 'unconditional_offer' and verified_by is not null and verified_at is not null))
);
create index applications_student_deadline_idx on public.applications(student_id, deadline);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  mentor_id uuid references public.mentors(id),
  founder_id uuid references public.profiles(id),
  service_kind text not null,
  scheduled_at timestamptz not null,
  status public.lesson_status not null default 'scheduled',
  completed_at timestamptz,
  mentor_notes text not null default '',
  agreed_value_kzt integer not null default 5000 check (agreed_value_kzt >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (mentor_id is not null or founder_id is not null)
);
create index lessons_student_schedule_idx on public.lessons(student_id, scheduled_at);
create index lessons_mentor_schedule_idx on public.lessons(mentor_id, scheduled_at);

create table public.lesson_confirmations (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null unique references public.lessons(id),
  student_id uuid not null references public.students(id),
  confirmed boolean not null,
  dispute_reason text not null default '',
  recorded_at timestamptz not null default now(),
  check (confirmed or length(trim(dispute_reason)) > 0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  guardian_id uuid references public.parents(id),
  payment_kind text not null check (payment_kind in ('initial', 'remaining', 'mentor_compensation', 'founder_service', 'refund', 'expense', 'tax')),
  amount_kzt integer not null check (amount_kzt > 0),
  status text not null check (status in ('pending', 'received', 'approved', 'paid', 'refunded', 'disputed')),
  description text not null default '',
  related_service_id uuid,
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now()
);
create index payments_student_date_idx on public.payments(student_id, recorded_at desc);

create table public.refund_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  guardian_id uuid not null references public.parents(id),
  requested_at timestamptz not null default now(),
  reason text not null default '',
  status public.refund_status not null default 'requested',
  amount_paid_kzt integer,
  delivered_service_value_kzt integer,
  calculated_refund_kzt integer,
  decision_note text not null default '',
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  processed_at timestamptz,
  check (calculated_refund_kzt is null or calculated_refund_kzt >= 0)
);
create index refund_requests_status_idx on public.refund_requests(status, requested_at);

create table public.mentor_earnings (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.mentors(id),
  lesson_id uuid not null unique references public.lessons(id),
  amount_kzt integer not null check (amount_kzt = 5000),
  earned_at timestamptz not null default now(),
  paid_out_at timestamptz
);
create index mentor_earnings_mentor_idx on public.mentor_earnings(mentor_id, earned_at desc);

create table public.mentor_payouts (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.mentors(id),
  amount_kzt integer not null check (amount_kzt > 0),
  paid_at timestamptz not null,
  reference text not null default '',
  recorded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  title text not null,
  category text not null default '',
  description text not null default '',
  achieved_on date,
  source_url text,
  created_at timestamptz not null default now()
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  organization text not null,
  description text not null default '',
  country text not null default '',
  eligibility jsonb not null default '{}',
  deadline date,
  cost text not null default '',
  official_url text not null,
  source_verified_at timestamptz,
  ai_eligibility_assumption text not null default '',
  published boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.student_opportunities (
  opportunity_id uuid not null references public.opportunities(id),
  student_id uuid not null references public.students(id),
  status public.opportunity_status not null default 'recommended',
  assigned_by uuid references public.profiles(id),
  assigned_at timestamptz not null default now(),
  student_note text not null default '',
  primary key (opportunity_id, student_id)
);
create index student_opportunities_student_idx on public.student_opportunities(student_id, assigned_at desc);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  title text not null,
  details text not null default '',
  due_date date,
  completed_at timestamptz,
  assigned_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index tasks_student_due_idx on public.tasks(student_id, due_date);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id),
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications(recipient_id, created_at desc);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  uploaded_by uuid not null references public.profiles(id),
  storage_path text not null unique,
  file_name text not null,
  document_kind text not null,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_created_idx on public.audit_logs(created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);

create or replace function private.current_role()
returns public.orta_role
language sql stable security definer
set search_path = ''
as $$
  select p.role from public.profiles p where p.id = (select auth.uid())
$$;
revoke all on function private.current_role() from public, anon;
grant execute on function private.current_role() to authenticated;

create or replace function private.can_access_student(p_student_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select
    private.current_role() = 'founder'
    or p_student_id = (select auth.uid())
    or exists (select 1 from public.student_guardians g where g.student_id = p_student_id and g.guardian_id = (select auth.uid()))
    or exists (select 1 from public.student_mentors sm where sm.student_id = p_student_id and sm.mentor_id = (select auth.uid()))
$$;
revoke all on function private.can_access_student(uuid) from public, anon;
grant execute on function private.can_access_student(uuid) to authenticated;

create or replace function private.is_assigned_mentor(p_student_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.student_mentors sm
    where sm.student_id = p_student_id and sm.mentor_id = (select auth.uid())
  )
$$;
revoke all on function private.is_assigned_mentor(uuid) from public, anon;
grant execute on function private.is_assigned_mentor(uuid) to authenticated;

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
  if new.raw_app_meta_data ->> 'role' = 'founder' then
    assigned_role := 'founder';
  else
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
  end if;

  insert into public.profiles(id, role, full_name)
  values (new.id, assigned_role, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
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

create table public.registration_invites (
  id uuid primary key default gen_random_uuid(),
  code uuid not null unique default gen_random_uuid(),
  email text,
  role public.orta_role not null check (role in ('student', 'mentor', 'parent')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  created_by uuid not null references public.profiles(id),
  used_by uuid references auth.users(id),
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index registration_invites_code_idx on public.registration_invites(code) where used_at is null;

create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute procedure private.handle_new_user();

create or replace function private.record_audit_event()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  old_json jsonb;
  new_json jsonb;
  row_id text;
begin
  if tg_op <> 'INSERT' then old_json := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then new_json := to_jsonb(new); end if;
  row_id := coalesce(new_json ->> 'id', new_json ->> 'student_id', new_json ->> 'profile_id',
                     old_json ->> 'id', old_json ->> 'student_id', old_json ->> 'profile_id', 'unknown');
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_values, new_values)
  values ((select auth.uid()), tg_op, tg_table_name, row_id, old_json, new_json);
  return coalesce(new, old);
end;
$$;
revoke all on function private.record_audit_event() from public, anon, authenticated;

create or replace function private.confirm_lesson()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  lesson_row public.lessons%rowtype;
begin
  if new.student_id <> (select auth.uid()) then
    raise exception 'A student can only confirm their own consultation.';
  end if;
  select * into lesson_row from public.lessons l
    where l.id = new.lesson_id and l.student_id = new.student_id for update;
  if not found or lesson_row.status <> 'conducted' then
    raise exception 'Only a consultation marked conducted can be confirmed or disputed.';
  end if;
  if new.confirmed then
    update public.lessons set status = 'confirmed', updated_at = now() where id = new.lesson_id;
    if lesson_row.mentor_id is not null then
      insert into public.mentor_earnings(mentor_id, lesson_id, amount_kzt)
      values (lesson_row.mentor_id, lesson_row.id, 5000)
      on conflict (lesson_id) do nothing;
    end if;
  else
    update public.lessons set status = 'disputed', updated_at = now() where id = new.lesson_id;
  end if;
  return new;
end;
$$;
revoke all on function private.confirm_lesson() from public, anon, authenticated;

create trigger lesson_confirmation_workflow
after insert on public.lesson_confirmations
for each row execute procedure private.confirm_lesson();

create or replace function public.create_registration_invite(
  p_role public.orta_role,
  p_email text default null
)
returns table(code uuid, expires_at timestamptz)
language plpgsql security invoker
set search_path = ''
as $$
begin
  if private.current_role() <> 'founder' then
    raise exception 'Founder access required.';
  end if;
  if p_role not in ('student', 'mentor', 'parent') then
    raise exception 'Unsupported invitation role.';
  end if;
  return query
    insert into public.registration_invites(role, email, created_by)
    values (p_role, nullif(lower(trim(p_email)), ''), (select auth.uid()))
    returning registration_invites.code, registration_invites.expires_at;
end;
$$;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.parents enable row level security;
alter table public.student_guardians enable row level security;
alter table public.mentors enable row level security;
alter table public.student_mentors enable row level security;
alter table public.enrollments enable row level security;
alter table public.universities enable row level security;
alter table public.applications enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_confirmations enable row level security;
alter table public.payments enable row level security;
alter table public.refund_requests enable row level security;
alter table public.mentor_earnings enable row level security;
alter table public.mentor_payouts enable row level security;
alter table public.achievements enable row level security;
alter table public.opportunities enable row level security;
alter table public.student_opportunities enable row level security;
alter table public.tasks enable row level security;
alter table public.notifications enable row level security;
alter table public.documents enable row level security;
alter table public.audit_logs enable row level security;
alter table public.registration_invites enable row level security;

grant select on public.profiles to authenticated;
grant update (full_name, phone) on public.profiles to authenticated;
grant select, update on public.students to authenticated;
grant select on public.parents, public.mentors to authenticated;
grant select, insert, update, delete on public.student_guardians, public.student_mentors to authenticated;
grant select, insert, update on public.enrollments to authenticated;
grant select, insert, update on public.universities to authenticated;
grant select, insert, update on public.applications to authenticated;
grant select, insert, update on public.lessons to authenticated;
grant select, insert on public.lesson_confirmations to authenticated;
grant select, insert on public.payments to authenticated;
grant select, insert, update on public.refund_requests to authenticated;
grant select on public.mentor_earnings to authenticated;
grant select, insert on public.mentor_payouts to authenticated;
grant select, insert, update on public.achievements to authenticated;
grant select, insert, update on public.opportunities to authenticated;
grant select, insert, update on public.student_opportunities to authenticated;
grant select, insert, update on public.tasks to authenticated;
grant select, insert, update on public.notifications to authenticated;
grant select, insert on public.documents to authenticated;
grant select on public.audit_logs to authenticated;
grant select, insert, update on public.registration_invites to authenticated;
grant execute on function public.create_registration_invite(public.orta_role, text) to authenticated;
grant usage, select on sequence public.audit_logs_id_seq to authenticated;

create policy profiles_read on public.profiles for select to authenticated
using (id = (select auth.uid()) or private.current_role() = 'founder' or private.can_access_student(id));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy students_read on public.students for select to authenticated
using (private.can_access_student(id));
create policy students_update_self_or_founder on public.students for update to authenticated
using (id = (select auth.uid()) or private.current_role() = 'founder')
with check (id = (select auth.uid()) or private.current_role() = 'founder');

create policy parents_read on public.parents for select to authenticated
using (id = (select auth.uid()) or private.current_role() = 'founder'
  or exists (select 1 from public.student_guardians g where g.guardian_id = id and private.can_access_student(g.student_id)));
create policy guardians_read on public.student_guardians for select to authenticated
using (private.current_role() = 'founder' or private.can_access_student(student_id) or guardian_id = (select auth.uid()));
create policy guardians_manage on public.student_guardians for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy mentors_read on public.mentors for select to authenticated
using (private.current_role() = 'founder' or id = (select auth.uid())
  or exists (select 1 from public.student_mentors sm where sm.mentor_id = id and private.can_access_student(sm.student_id)));
create policy student_mentors_read on public.student_mentors for select to authenticated
using (private.current_role() = 'founder' or private.can_access_student(student_id) or mentor_id = (select auth.uid()));
create policy student_mentors_founder on public.student_mentors for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy enrollments_read on public.enrollments for select to authenticated using (private.can_access_student(student_id));
create policy enrollments_founder on public.enrollments for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy universities_read on public.universities for select to authenticated using (true);
create policy universities_founder on public.universities for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy applications_read on public.applications for select to authenticated using (private.can_access_student(student_id));
create policy applications_student_insert on public.applications for insert to authenticated
with check (student_id = (select auth.uid()) or private.current_role() = 'founder');
create policy applications_student_update on public.applications for update to authenticated
using (student_id = (select auth.uid()) or private.current_role() = 'founder')
with check (student_id = (select auth.uid()) or private.current_role() = 'founder');

create policy lessons_read on public.lessons for select to authenticated
using (private.can_access_student(student_id));
create policy lessons_founder_insert on public.lessons for insert to authenticated
with check (private.current_role() = 'founder');
create policy lessons_mentor_update on public.lessons for update to authenticated
using (private.current_role() = 'founder' or private.is_assigned_mentor(student_id))
with check (private.current_role() = 'founder' or (private.is_assigned_mentor(student_id) and status = 'conducted'));

create policy lesson_confirmations_read on public.lesson_confirmations for select to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid())
  or private.is_assigned_mentor(student_id));
create policy lesson_confirmations_student_insert on public.lesson_confirmations for insert to authenticated
with check (student_id = (select auth.uid()));

create policy payments_read on public.payments for select to authenticated
using (private.current_role() = 'founder' or private.can_access_student(student_id));
create policy payments_founder_insert on public.payments for insert to authenticated
with check (private.current_role() = 'founder' and recorded_by = (select auth.uid()));

create policy refunds_read on public.refund_requests for select to authenticated
using (private.current_role() = 'founder' or guardian_id = (select auth.uid()));
create policy refunds_guardian_insert on public.refund_requests for insert to authenticated
with check (guardian_id = (select auth.uid()) and exists (
  select 1 from public.student_guardians g where g.student_id = student_id and g.guardian_id = (select auth.uid())
));
create policy refunds_founder_update on public.refund_requests for update to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy earnings_read on public.mentor_earnings for select to authenticated
using (private.current_role() = 'founder' or mentor_id = (select auth.uid()));
create policy payouts_read on public.mentor_payouts for select to authenticated
using (private.current_role() = 'founder' or mentor_id = (select auth.uid()));
create policy payouts_founder_insert on public.mentor_payouts for insert to authenticated
with check (private.current_role() = 'founder' and recorded_by = (select auth.uid()));

create policy achievements_read on public.achievements for select to authenticated using (private.can_access_student(student_id));
create policy achievements_manage on public.achievements for all to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid()))
with check (private.current_role() = 'founder' or student_id = (select auth.uid()));

create policy opportunities_read on public.opportunities for select to authenticated
using (private.current_role() = 'founder' or (published and exists (
  select 1 from public.student_opportunities so where so.opportunity_id = id and so.student_id = (select auth.uid())
)));
create policy opportunities_founder_manage on public.opportunities for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create policy student_opportunities_read on public.student_opportunities for select to authenticated
using (private.current_role() = 'founder' or private.can_access_student(student_id));
create policy student_opportunities_founder_manage on public.student_opportunities for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy student_opportunities_student_update on public.student_opportunities for update to authenticated
using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));

create policy tasks_read on public.tasks for select to authenticated using (private.can_access_student(student_id));
create policy tasks_founder_manage on public.tasks for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy tasks_student_update on public.tasks for update to authenticated
using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));

create policy notifications_read on public.notifications for select to authenticated
using (recipient_id = (select auth.uid()) or private.current_role() = 'founder');
create policy notifications_update_self on public.notifications for update to authenticated
using (recipient_id = (select auth.uid())) with check (recipient_id = (select auth.uid()));

create policy documents_read on public.documents for select to authenticated
using (private.current_role() = 'founder' or private.can_access_student(student_id));
create policy documents_student_insert on public.documents for insert to authenticated
with check (uploaded_by = (select auth.uid()) and student_id = (select auth.uid()));
create policy audit_logs_founder_read on public.audit_logs for select to authenticated
using (private.current_role() = 'founder');

create policy invites_founder_manage on public.registration_invites for all to authenticated
using (private.current_role() = 'founder') with check (private.current_role() = 'founder');

create trigger audit_profiles after insert or update or delete on public.profiles for each row execute procedure private.record_audit_event();
create trigger audit_enrollments after insert or update or delete on public.enrollments for each row execute procedure private.record_audit_event();
create trigger audit_applications after insert or update or delete on public.applications for each row execute procedure private.record_audit_event();
create trigger audit_lessons after insert or update or delete on public.lessons for each row execute procedure private.record_audit_event();
create trigger audit_payments after insert or update or delete on public.payments for each row execute procedure private.record_audit_event();
create trigger audit_refunds after insert or update or delete on public.refund_requests for each row execute procedure private.record_audit_event();
create trigger audit_earnings after insert or update or delete on public.mentor_earnings for each row execute procedure private.record_audit_event();
create trigger audit_payouts after insert or update or delete on public.mentor_payouts for each row execute procedure private.record_audit_event();
create trigger audit_opportunities after insert or update or delete on public.opportunities for each row execute procedure private.record_audit_event();
create trigger audit_assignments after insert or update or delete on public.student_mentors for each row execute procedure private.record_audit_event();

-- New Supabase projects may not expose new public tables through the Data API by default.
-- These grants are deliberately explicit; RLS remains the row-level authorization boundary.
grant select, update on public.profiles to authenticated;
grant select, update on public.students to authenticated;
grant select on public.parents, public.mentors to authenticated;
grant select, insert, update, delete on public.student_guardians, public.student_mentors to authenticated;
grant select, insert, update on public.enrollments, public.universities, public.applications, public.lessons to authenticated;
grant select, insert on public.lesson_confirmations, public.payments, public.documents to authenticated;
grant select, insert, update on public.refund_requests to authenticated;
grant select on public.mentor_earnings, public.audit_logs to authenticated;
grant select, insert on public.mentor_payouts to authenticated;
grant select, insert, update on public.achievements, public.opportunities, public.student_opportunities, public.tasks, public.notifications, public.registration_invites to authenticated;
grant execute on function public.create_registration_invite(public.orta_role, text) to authenticated;
;
