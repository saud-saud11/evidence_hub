enum UserRole {
  admin,
  editor,
  viewer;

  static UserRole fromString(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'editor':
        return UserRole.editor;
      case 'viewer':
      default:
        return UserRole.viewer;
    }
  }

  String get nameStr => name;
}
