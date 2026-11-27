-- Per-account product mode and founder-issued Academy activation codes.
alter table public.profiles
  add column if not exists app_mode text
  check (app_mode is null or app_mode in ('personal', 'academy'));

create table if not exists public.academy_activation_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  expires_at timestamptz,
  max_uses integer not null default 1 check (max_uses > 0),
  used_count integer not null default 0 check (used_count >= 0),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.academy_activation_codes enable row level security;

create or replace function public.activate_orta_academy(p_code text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_role public.orta_role;
begin
  if v_user is null then return false; end if;
  select role into v_role from public.profiles where id = v_user for update;
  if v_role is null or v_role in ('founder', 'mentor') then return false; end if;
  update public.academy_activation_codes
    set used_count = used_count + 1
    where code_hash = encode(extensions.digest(upper(trim(p_code)), 'sha256'), 'hex')
      and used_count < max_uses and (expires_at is null or expires_at > now());
  if not found then return false; end if;
  update public.profiles set app_mode = 'academy', updated_at = now() where id = v_user;
  return true;
end $$;
revoke all on function public.activate_orta_academy(text) from public;
grant execute on function public.activate_orta_academy(text) to authenticated;

create or replace function public.issue_orta_academy_code(p_code text, p_expires_at timestamptz default null, p_max_uses integer default 1)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'founder') then
    raise exception 'Founder access required';
  end if;
  if p_code is null or length(trim(p_code)) < 12 or p_max_uses < 1 then
    raise exception 'Invalid code parameters';
  end if;
  insert into public.academy_activation_codes(code_hash, expires_at, max_uses, created_by)
  values (encode(extensions.digest(upper(trim(p_code)), 'sha256'), 'hex'), p_expires_at, p_max_uses, auth.uid());
end $$;
revoke all on function public.issue_orta_academy_code(text, timestamptz, integer) from public;
grant execute on function public.issue_orta_academy_code(text, timestamptz, integer) to authenticated;

create or replace function public.is_language_orta_student()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid()
    and (role = 'student' or app_mode = 'personal'));
$$;
