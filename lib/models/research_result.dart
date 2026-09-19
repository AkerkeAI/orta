enum VerificationStatus { unknown, checked, needsReview }

class ResearchResult {
  final String title;
  final String sourceUrl;
  final String sourceName;
  final DateTime retrievedAt;
  final String summary;
  final VerificationStatus verificationStatus;

  const ResearchResult({
    required this.title,
    required this.sourceUrl,
    required this.sourceName,
    required this.retrievedAt,
    required this.summary,
    this.verificationStatus = VerificationStatus.unknown,
  });
}
