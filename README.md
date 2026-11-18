# ORTA Admissions

ORTA is a university admissions and mentorship platform for students in Kazakhstan applying abroad. The app is organized around three roles: Founder, Student and Mentor.

## Current app

The Flutter app opens the authenticated Supabase admissions workspace when configured. Without Supabase configuration it shows a setup message; the demo dashboard with its role preview switch is not exposed as an application entry point. Values and people shown in the demo screen remain sample content for the existing preview implementation.

See [PRODUCT_REQUIREMENTS.md](PRODUCT_REQUIREMENTS.md) for the business rules, role boundaries and production readiness gaps. The project overview supplied by the user remains the detailed product specification.

## Production services still required

The app now connects to Supabase Auth and reads role-scoped records from PostgreSQL. Founder invitation creation, mentor lesson completion, student lesson confirmation/dispute, and Founder unconditional-offer verification are wired to database policies. The current project still needs document storage, fuller CRUD screens, payment provider integration, and admissions-specific AI actions.

### Supabase app configuration

The project URL and publishable key are supplied at launch and are not committed to the source tree:

```bash
flutter run --dart-define=SUPABASE_URL=https://gjjayhhumqmkcauxbpmg.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

The publishable key is intended for client applications. Never place a Supabase secret or service-role key in Flutter.

### First Founder account

The initial Founder must be provisioned by an organization administrator. In the ORTA Supabase SQL editor, create a short-lived invitation addressed to the Founder’s email:

```sql
insert into public.registration_invites (role, email, created_by, expires_at)
values ('founder', lower('FOUNDER_EMAIL'), null, now() + interval '1 hour')
returning code;
```

Use the returned code in the app’s account-creation form with that same email. After that, the Founder can issue student, mentor and guardian invitations inside ORTA. Founder invitations are deliberately unavailable through the app.

The Supabase project is currently in `eu-west-1`. The project overview calls for Kazakhstan data storage; confirm the data-residency and cross-border processing setup before entering real student or guardian information.

Roles are assigned by the database auth-user trigger from a valid, single-use invitation. Founder bootstrap requires a Founder invitation created through trusted Supabase administration. Authenticated clients cannot update `profiles.role`; role changes require a trusted server-side/admin database workflow. Do not change roles from client code or user-editable auth metadata. The `interface_language` profile field stores the UI language (`en`, `ru`, or `kk`), while practice languages and levels are separate rows in `language_profiles`.

Apply the local migration `supabase/migrations/20261115120000_lock_roles_and_profile_locale.sql` using the reviewed Supabase migration workflow before publishing the app. No remote migration is applied by this repository change.

Before applying, check for existing Auth users without a profile row. The migration preserves existing profile/account data and does not delete users, but such an account must be repaired through the trusted admin workflow so the auth-user trigger can remain atomic:

```sql
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
```

## Flutter app

The cross-platform Flutter app is in the repository root. Run with `flutter run`. Targets include Android, iOS, macOS, Linux, Windows and web.

## Backend and landing page

`backend/` contains the earlier ORTA conversational AI service and is not yet an admissions backend. `landing/` is the separate public-facing site.
