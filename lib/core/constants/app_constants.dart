class AppConstants {
  static const String appName = 'Evidence Hub';
  
  // File size limit (15 MB in bytes)
  static const int maxFileSize = 15 * 1024 * 1024;
  
  // Allowed file upload extensions
  static const List<String> allowedFileExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'png',
    'jpg',
    'jpeg'
  ];

  // SharedPreferences keys
  static const String keyLocale = 'preferred_locale';
  static const String keyThemeMode = 'preferred_theme';
}
