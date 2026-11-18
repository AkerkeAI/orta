
-- Language ORTA: student-owned practice data.
-- Founder and Mentor receive no policies and cannot read practice conversations.
-- Core admissions tables are not modified.

-- Check whether the authenticated user is a student.
create or replace function public.is_language_orta_student()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'student'
  );
$$;

revoke all on function public.is_language_orta_student() from public;
grant execute on function public.is_language_orta_student() to authenticated;


-- Student language profiles.
create table if not exists public.language_profiles (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null
    references public.profiles(id) on delete cascade,

  language_code text not null
    check (char_length(language_code) between 2 and 8),
  language_name text not null
    check (char_length(language_name) between 1 and 80),

  current_level text not null default 'A1'
    check (current_level in ('A1','A2','B1','B2','C1','C2')),
  target_level text not null default 'B2'
    check (target_level in ('A1','A2','B1','B2','C1','C2')),

  goals text not null default ''
    check (char_length(goals) <= 2000),
  preferred_areas text[] not null default '{}',
  skill_progress jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (student_id, language_code),

  -- Required for composite foreign keys.
  unique (id, student_id)
);


-- Student practice sessions.
create table if not exists public.language_practice_sessions (
  id uuid primary key default gen_random_uuid(),

  student_id uuid not null
    references public.profiles(id) on delete cascade,

  profile_id uuid not null,

  skill text not null
    check (skill in (
      'speaking',
      'writing',
      'listening',
      'reading',
      'vocabulary',
      'scenario',
      'conversation'
    )),

  scenario_key text not null
    check (char_length(scenario_key) <= 64),

  prompt text not null default ''
    check (char_length(prompt) <= 8000),
  stimulus text not null default ''
    check (char_length(stimulus) <= 8000),
  student_response text not null default ''
    check (char_length(student_response) <= 8000),
  transcript text not null default ''
    check (char_length(transcript) <= 16000),

  status text not null default 'in_progress'
    check (status in ('in_progress','completed')),

  created_at timestamptz not null default now(),
  completed_at timestamptz,

  -- Required for composite foreign keys.
  unique (id, student_id),

  -- A session can only reference a profile owned by the same student.
  constraint language_sessions_profile_owner_fk
    foreign key (profile_id, student_id)
    references public.language_profiles(id, student_id)
    on delete cascade
);


-- Results of student practice sessions.
create table if not exists public.language_session_results (
  id uuid primary key default gen_random_uuid(),

  session_id uuid not null,
  student_id uuid not null
    references public.profiles(id) on delete cascade,

  original_response text not null default ''
    check (char_length(original_response) <= 8000),
  corrections text not null default ''
    check (char_length(corrections) <= 8000),
  explanation text not null default ''
    check (char_length(explanation) <= 8000),
  alternative_phrasing text not null default ''
    check (char_length(alternative_phrasing) <= 8000),

  vocabulary jsonb not null default '[]'::jsonb,

  feedback text not null default ''
    check (char_length(feedback) <= 8000),

  ai_available boolean not null default false,
  created_at timestamptz not null default now(),

  -- One result per session.
  unique (session_id),

  -- Required for the composite foreign key.
  unique (session_id, student_id),

  -- A result can only reference a session owned by the same student.
  constraint language_results_session_owner_fk
    foreign key (session_id, student_id)
    references public.language_practice_sessions(id, student_id)
    on delete cascade
);


-- Indexes.
create index if not exists language_profiles_student_idx
  on public.language_profiles (student_id);

create index if not exists language_practice_sessions_student_idx
  on public.language_practice_sessions (student_id, created_at desc);

create index if not exists language_practice_sessions_profile_idx
  on public.language_practice_sessions (profile_id, created_at desc);

create index if not exists language_session_results_student_idx
  on public.language_session_results (student_id);


-- Automatically update language profile timestamps.
create or replace function public.touch_language_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists language_profiles_touch_updated_at
  on public.language_profiles;

create trigger language_profiles_touch_updated_at
before update on public.language_profiles
for each row
execute function public.touch_language_profile_updated_at();


-- Enable and enforce Row Level Security.
alter table public.language_profiles enable row level security;
alter table public.language_practice_sessions enable row level security;
alter table public.language_session_results enable row level security;

alter table public.language_profiles force row level security;
alter table public.language_practice_sessions force row level security;
alter table public.language_session_results force row level security;


-- Remove access from public and anonymous users.
revoke all on public.language_profiles from public, anon;
revoke all on public.language_practice_sessions from public, anon;
revoke all on public.language_session_results from public, anon;

-- Authenticated users receive table privileges,
-- but RLS restricts access to their own records.
grant select, insert, update, delete
  on public.language_profiles to authenticated;

grant select, insert, update, delete
  on public.language_practice_sessions to authenticated;

grant select, insert, update, delete
  on public.language_session_results to authenticated;


-- Student-only policies.
drop policy if exists language_profiles_student_all
  on public.language_profiles;

create policy language_profiles_student_all
on public.language_profiles
for all
to authenticated
using (
  student_id = auth.uid()
  and public.is_language_orta_student()
)
with check (
  student_id = auth.uid()
  and public.is_language_orta_student()
);


drop policy if exists language_practice_sessions_student_all
  on public.language_practice_sessions;

create policy language_practice_sessions_student_all
on public.language_practice_sessions
for all
to authenticated
using (
  student_id = auth.uid()
  and public.is_language_orta_student()
)
with check (
  student_id = auth.uid()
  and public.is_language_orta_student()
);


drop policy if exists language_session_results_student_all
  on public.language_session_results;

create policy language_session_results_student_all
on public.language_session_results
for all
to authenticated
using (
  student_id = auth.uid()
  and public.is_language_orta_student()
)
with check (
  student_id = auth.uid()
  and public.is_language_orta_student()
);
