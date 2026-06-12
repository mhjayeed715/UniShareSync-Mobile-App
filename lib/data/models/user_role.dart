enum UserRole {
  student,
  faculty,
  admin,
  driver;

  String get value => name;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.faculty:
        return 'Faculty';
      case UserRole.admin:
        return 'Admin';
      case UserRole.driver:
        return 'Bus Driver';
    }
  }

  static UserRole fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
