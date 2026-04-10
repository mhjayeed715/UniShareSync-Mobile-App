enum UserRole {
  student,
  faculty,
  admin;

  String get value => name;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
