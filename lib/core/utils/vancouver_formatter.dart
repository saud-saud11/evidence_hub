class VancouverFormatter {
  static String format({
    required String title,
    required String organization,
    required int publicationYear,
  }) {
    // Standard Vancouver format: Author/Organization. Title. City: Publisher; Year.
    final cleanOrg = organization.trim();
    final cleanTitle = title.trim();
    return '$cleanOrg. $cleanTitle. Riyadh: $cleanOrg; $publicationYear.';
  }
}
