import '../models/admissions_models.dart';
import '../models/language_orta_models.dart';

export '../models/language_orta_models.dart' show LanguageOrtaDenied;

class LanguageOrtaAccess {
  static const moduleName = 'Language ORTA';

  static bool canOpenRole(String role) => role.trim().toLowerCase() == 'student';

  static bool canOpen(OrtaRole role) => role == OrtaRole.student;

  static List<String> studentSections(List<String> base) => [
    ...base,
    if (!base.contains(moduleName)) moduleName,
  ];

  static List<String> sectionsForRole(String role, List<String> base) =>
      canOpenRole(role) ? studentSections(base) : List<String>.from(base);

  static void assertStudent({required String role, required String studentId}) {
    if (!canOpenRole(role) || studentId.trim().isEmpty) {
      throw const LanguageOrtaDenied(
        'Language ORTA is available only to authenticated students.',
      );
    }
  }

  static bool owns({
    required String role,
    required String requesterId,
    required String ownerId,
  }) => canOpenRole(role) && requesterId.isNotEmpty && requesterId == ownerId;
}
