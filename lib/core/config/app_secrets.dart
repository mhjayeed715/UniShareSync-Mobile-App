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

  static const passwordRecoveryRedirectTo = String.fromEnvironment(
    'PASSWORD_RECOVERY_REDIRECT_TO',
    defaultValue: 'unisharesync://reset-password',
  );
}
