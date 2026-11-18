/// Admissions domain records used by the ORTA admissions workspace.
///
/// These immutable value objects keep financial and service-delivery facts
/// separate from personal profile data. Production persistence and access
/// control belong in the authenticated server/database layer.
enum OrtaRole { founder, student, mentor }

enum OrtaProgramType { standard, intensive }

enum ApplicationStatus {
  notStarted,
  inPreparation,
  submitted,
  underReview,
  conditionalOffer,
  unconditionalOffer,
  rejected,
  waitlisted,
  withdrawn,
}

enum LessonStatus { scheduled, conducted, awaitingStudent, confirmed, disputed }

enum PaymentKind {
  initial,
  remaining,
  mentorCompensation,
  refund,
  expense,
  tax,
}

enum PaymentStatus { pending, received, approved, paid, refunded, disputed }

class GuardianRecord {
  const GuardianRecord({
    required this.name,
    required this.email,
    this.phone = '',
  });
  final String name;
  final String email;
  final String phone;
}

class AdmissionsStudent {
  const AdmissionsStudent({
    required this.id,
    required this.name,
    required this.grade,
    required this.program,
    required this.startDate,
    required this.consultationEndDate,
    this.guardian,
    this.countries = const [],
    this.intendedMajors = const [],
    this.englishLevel = '',
    this.examScores = const {},
    this.mentorIds = const [],
    this.active = true,
  });
  final String id;
  final String name;
  final int grade;
  final OrtaProgramType program;
  final DateTime startDate;
  final DateTime consultationEndDate;
  final GuardianRecord? guardian;
  final List<String> countries;
  final List<String> intendedMajors;
  final String englishLevel;
  final Map<String, String> examScores;
  final List<String> mentorIds;
  final bool active;
}

class MentorRecord {
  const MentorRecord({
    required this.id,
    required this.name,
    required this.specialization,
    this.assignedStudentIds = const [],
    this.compensationPerLessonKzt = 5000,
  });
  final String id;
  final String name;
  final String specialization;
  final List<String> assignedStudentIds;
  final int compensationPerLessonKzt;
}

class AdmissionsProgramPlan {
  const AdmissionsProgramPlan({
    required this.program,
    required this.startDate,
    required this.endDate,
  });
  final OrtaProgramType program;
  final DateTime startDate;
  final DateTime endDate;

  int get availableWeeklyConsultations {
    if (endDate.isBefore(startDate)) return 0;
    return (endDate.difference(startDate).inDays ~/ 7) + 1;
  }

  int get expertConsultations => program == OrtaProgramType.standard
      ? 18
      : availableWeeklyConsultations.clamp(0, 18).toInt();
  int get founderMentorshipSlots =>
      program == OrtaProgramType.intensive ? 18 - expertConsultations : 0;
  int mentorForSlot(int slot) => slot.isEven ? 0 : 1; // USA, China alternating.
}

class UniversityApplication {
  const UniversityApplication({
    required this.id,
    required this.studentId,
    required this.university,
    required this.country,
    required this.program,
    required this.status,
    this.deadline,
    this.officialSource,
    this.decisionDate,
    this.documentChecklist = const {},
  });
  final String id;
  final String studentId;
  final String university;
  final String country;
  final String program;
  final ApplicationStatus status;
  final DateTime? deadline;
  final Uri? officialSource;
  final DateTime? decisionDate;
  final Map<String, bool> documentChecklist;
}

class ConsultationRecord {
  const ConsultationRecord({
    required this.id,
    required this.studentId,
    required this.mentorId,
    required this.scheduledAt,
    required this.kind,
    this.status = LessonStatus.scheduled,
    this.completedAt,
    this.studentConfirmedAt,
    this.agreedValueKzt = 5000,
    this.notes = '',
  });
  final String id;
  final String studentId;
  final String mentorId;
  final DateTime scheduledAt;
  final String kind;
  final LessonStatus status;
  final DateTime? completedAt;
  final DateTime? studentConfirmedAt;
  final int agreedValueKzt;
  final String notes;

  bool get earnsMentorCompensation => status == LessonStatus.confirmed;
}

class FinancialRecord {
  const FinancialRecord({
    required this.id,
    required this.studentId,
    required this.kind,
    required this.amountKzt,
    required this.status,
    required this.recordedAt,
    this.description = '',
    this.relatedServiceId,
  });
  final String id;
  final String studentId;
  final PaymentKind kind;
  final int amountKzt;
  final PaymentStatus status;
  final DateTime recordedAt;
  final String description;
  final String? relatedServiceId;
}

class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.studentId,
    required this.requestedAt,
    required this.deliveredServiceValueKzt,
    required this.amountPaidKzt,
    this.decision,
    this.decisionNote = '',
    this.reviewedAt,
  });
  final String id;
  final String studentId;
  final DateTime requestedAt;
  final int deliveredServiceValueKzt;
  final int amountPaidKzt;
  final String? decision;
  final String decisionNote;
  final DateTime? reviewedAt;

  int get indicativeRefundKzt => (amountPaidKzt - deliveredServiceValueKzt)
      .clamp(0, amountPaidKzt)
      .toInt();
}

class OpportunityRecord {
  const OpportunityRecord({
    required this.id,
    required this.title,
    required this.organization,
    required this.country,
    required this.deadline,
    required this.officialSource,
    required this.lastVerifiedAt,
    this.description = '',
    this.eligibility = const [],
    this.cost = '',
    this.studentIds = const [],
    this.aiEligibilityAssumption = '',
  });
  final String id;
  final String title;
  final String organization;
  final String country;
  final DateTime deadline;
  final Uri officialSource;
  final DateTime lastVerifiedAt;
  final String description;
  final List<String> eligibility;
  final String cost;
  final List<String> studentIds;
  final String aiEligibilityAssumption;
}

class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.actorId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.before = const {},
    this.after = const {},
  });
  final String id;
  final String actorId;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
}
