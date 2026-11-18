drop policy achievements_manage on public.achievements;
create policy achievements_insert on public.achievements for insert to authenticated
with check (private.current_role() = 'founder' or student_id = (select auth.uid()));
create policy achievements_update on public.achievements for update to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid()))
with check (private.current_role() = 'founder' or student_id = (select auth.uid()));
create policy achievements_delete on public.achievements for delete to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid()));

drop policy enrollments_founder on public.enrollments;
create policy enrollments_insert_founder on public.enrollments for insert to authenticated with check (private.current_role() = 'founder');
create policy enrollments_update_founder on public.enrollments for update to authenticated using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy enrollments_delete_founder on public.enrollments for delete to authenticated using (private.current_role() = 'founder');

drop policy opportunities_founder_manage on public.opportunities;
create policy opportunities_insert_founder on public.opportunities for insert to authenticated with check (private.current_role() = 'founder');
create policy opportunities_update_founder on public.opportunities for update to authenticated using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy opportunities_delete_founder on public.opportunities for delete to authenticated using (private.current_role() = 'founder');

drop policy guardians_manage on public.student_guardians;
create policy guardians_insert_founder on public.student_guardians for insert to authenticated with check (private.current_role() = 'founder');
create policy guardians_update_founder on public.student_guardians for update to authenticated using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy guardians_delete_founder on public.student_guardians for delete to authenticated using (private.current_role() = 'founder');

drop policy student_mentors_founder on public.student_mentors;
create policy student_mentors_insert_founder on public.student_mentors for insert to authenticated with check (private.current_role() = 'founder');
create policy student_mentors_update_founder on public.student_mentors for update to authenticated using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy student_mentors_delete_founder on public.student_mentors for delete to authenticated using (private.current_role() = 'founder');

drop policy student_opportunities_founder_manage on public.student_opportunities;
drop policy student_opportunities_student_update on public.student_opportunities;
create policy student_opportunities_insert_founder on public.student_opportunities for insert to authenticated with check (private.current_role() = 'founder');
create policy student_opportunities_update on public.student_opportunities for update to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid()))
with check (private.current_role() = 'founder' or student_id = (select auth.uid()));
create policy student_opportunities_delete_founder on public.student_opportunities for delete to authenticated using (private.current_role() = 'founder');

drop policy tasks_founder_manage on public.tasks;
drop policy tasks_student_update on public.tasks;
create policy tasks_insert_founder on public.tasks for insert to authenticated with check (private.current_role() = 'founder');
create policy tasks_update on public.tasks for update to authenticated
using (private.current_role() = 'founder' or student_id = (select auth.uid()))
with check (private.current_role() = 'founder' or student_id = (select auth.uid()));
create policy tasks_delete_founder on public.tasks for delete to authenticated using (private.current_role() = 'founder');

drop policy universities_founder on public.universities;
create policy universities_insert_founder on public.universities for insert to authenticated with check (private.current_role() = 'founder');
create policy universities_update_founder on public.universities for update to authenticated using (private.current_role() = 'founder') with check (private.current_role() = 'founder');
create policy universities_delete_founder on public.universities for delete to authenticated using (private.current_role() = 'founder');

create index achievements_student_idx on public.achievements(student_id);
create index applications_university_idx on public.applications(university_id);
create index applications_verified_by_idx on public.applications(verified_by);
create index documents_student_idx on public.documents(student_id);
create index documents_uploaded_by_idx on public.documents(uploaded_by);
create index enrollments_created_by_idx on public.enrollments(created_by);
create index lesson_confirmations_student_idx on public.lesson_confirmations(student_id);
create index lessons_founder_idx on public.lessons(founder_id);
create index mentor_payouts_mentor_idx on public.mentor_payouts(mentor_id);
create index mentor_payouts_recorded_by_idx on public.mentor_payouts(recorded_by);
create index opportunities_created_by_idx on public.opportunities(created_by);
create index payments_guardian_idx on public.payments(guardian_id);
create index payments_recorded_by_idx on public.payments(recorded_by);
create index refund_requests_guardian_idx on public.refund_requests(guardian_id);
create index refund_requests_reviewed_by_idx on public.refund_requests(reviewed_by);
create index refund_requests_student_idx on public.refund_requests(student_id);
create index registration_invites_created_by_idx on public.registration_invites(created_by);
create index registration_invites_used_by_idx on public.registration_invites(used_by);
create index student_mentors_assigned_by_idx on public.student_mentors(assigned_by);
create index student_opportunities_assigned_by_idx on public.student_opportunities(assigned_by);
create index tasks_assigned_by_idx on public.tasks(assigned_by);
create index universities_created_by_idx on public.universities(created_by);
;
