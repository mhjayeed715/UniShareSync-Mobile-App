class AppSecrets {
  const AppSecrets._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fdxluhqdhwtoobazobsi.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_bqenCjhWcC2aabOuQdA0vQ_7yeOOUEu',
  );

  static const fixedAdminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'mehrabjayeed715@gmail.com',
  );

  static const fixedAdminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: 'UniShareSync@Admin123',
  );

  static const fixedFacultyEmail = String.fromEnvironment(
    'FACULTY_EMAIL',
    defaultValue: 'faculty.demo@smuct.ac.bd',
  );

  static const fixedFacultyPassword = String.fromEnvironment(
    'FACULTY_PASSWORD',
    defaultValue: 'UniShareSync@Faculty123',
  );

  static const fixedStudentEmail = String.fromEnvironment(
    'STUDENT_EMAIL',
    defaultValue: 'student.demo@smuct.ac.bd',
  );

  static const fixedStudentPassword = String.fromEnvironment(
    'STUDENT_PASSWORD',
    defaultValue: 'UniShareSync@Student123',
  );

  static const passwordRecoveryRedirectTo = String.fromEnvironment(
    'PASSWORD_RECOVERY_REDIRECT_TO',
    defaultValue: 'unisharesync://reset-password',
  );

  // ── Predefined driver accounts (local credential check only) ─────────────
  // Each entry: [email, password, displayName, assignedRouteId, stableProfileId]
  static const List<List<String>> driverAccounts = [
    ['driver1@smuct.ac.bd',  'SMUCTDriver@01', 'Driver Karim',  'route-azimpur',  '00000001-0000-0000-0000-000000000001'],
    ['driver2@smuct.ac.bd',  'SMUCTDriver@02', 'Driver Rahim',  'route-azimpur',  '00000001-0000-0000-0000-000000000002'],
    ['driver3@smuct.ac.bd',  'SMUCTDriver@03', 'Driver Hasan',  'route-savar',    '00000001-0000-0000-0000-000000000003'],
    ['driver4@smuct.ac.bd',  'SMUCTDriver@04', 'Driver Salam',  'route-savar',    '00000001-0000-0000-0000-000000000004'],
    ['driver5@smuct.ac.bd',  'SMUCTDriver@05', 'Driver Jalal',  'route-gazipur',  '00000001-0000-0000-0000-000000000005'],
    ['driver6@smuct.ac.bd',  'SMUCTDriver@06', 'Driver Faruk',  'route-gazipur',  '00000001-0000-0000-0000-000000000006'],
    ['driver7@smuct.ac.bd',  'SMUCTDriver@07', 'Driver Milon',  'route-mirpur',   '00000001-0000-0000-0000-000000000007'],
    ['driver8@smuct.ac.bd',  'SMUCTDriver@08', 'Driver Ratan',  'route-mirpur',   '00000001-0000-0000-0000-000000000008'],
    ['driver9@smuct.ac.bd',  'SMUCTDriver@09', 'Driver Babul',  'route-rampura',  '00000001-0000-0000-0000-000000000009'],
    ['driver10@smuct.ac.bd', 'SMUCTDriver@10', 'Driver Masum',  'route-rampura',  '00000001-0000-0000-0000-000000000010'],
  ];
}
