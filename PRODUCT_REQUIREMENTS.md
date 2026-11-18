# ORTA Admissions Platform

ORTA is an AI-supported university admissions mentorship platform for students in Kazakhstan applying to universities abroad. The primary operating roles are Founder, Student and Mentor. Parents or legal guardians are the primary contracting party and payer when a student is a minor.

The product source of truth is the project overview supplied by the user. It defines admissions diagnostics, ORTA Standard and Intensive programs, university/application tracking, consultations, lesson confirmation, opportunity matching, payments/refunds, mentor earnings, and role-specific AI assistance.

## Core commercial rules

- ORTA Standard and ORTA Intensive are each priced at 200,000 KZT.
- The initial payment is 20,000 KZT: diagnostics 3,000; tracker 2,000; Founder, USA mentor and China mentor introductory consultations 5,000 KZT each.
- The remaining 180,000 KZT is triggered only after the Founder verifies a final unconditional offer from the mutually approved university list, subject to the signed agreement and applicable law.
- Standard has 18 weekly additional consultations, alternating USA and China mentors. Intensive calculates the consultations available in the agreed timeline and documents separately agreed Founder mentorship for unused slots.
- Mentor compensation is 5,000 KZT for each actually delivered and student-confirmed consultation. Disputes require Founder review.
- Refund calculations use services actually delivered and must remain subject to the signed contract and applicable Kazakhstan law. No pending or undelivered consultation is treated as completed.
- Financial changes, service delivery and administrative changes must have durable audit history.

## Role boundaries

- Founder: organization-wide student, mentor, service, opportunity, operational and financial administration.
- Student: own profile, applications, progress, consultations, payment information and published opportunities.
- Mentor: assigned students and consultations, own compensation and relevant lesson context only.
- Opportunities are available to Founder and Students, not Mentors.
- Role access must be enforced by authenticated server-side authorization and database Row Level Security, not by hiding interface controls.

## Current implementation status

The Flutter application now opens the admissions workspace with Founder, Student and Mentor interface previews. Sample dashboard values and people are illustrative UI data. The current app does not yet connect those screens to authentication, Supabase/PostgreSQL persistence, Row Level Security, payment processing, live university data or shared organization records. The preview role selector is not an authorization mechanism. Do not present sample values as real ORTA records or claim that financial, lesson or application actions have been persisted.

The current AI backend is a separate conversational/research service for the previous local-life product. Admissions-specific AI actions must be permission-scoped and provider-independent before being enabled in production.

## Required production architecture

Use Supabase Auth and PostgreSQL with database-enforced RLS. Keep financial records separate from profile data. Core entities include profiles, students, parents, mentors, programs, enrollments, lessons, lesson confirmations, payments, refunds, mentor earnings and payouts, universities, applications, achievements, opportunities and assignments, tasks, notifications, documents and audit logs. Configure storage and data processing for applicable Kazakhstan requirements before accepting real student information.
