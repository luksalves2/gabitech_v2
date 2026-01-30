/// Core configuration for Supabase connection
///
/// Values are read from `--dart-define` so we can separate dev/stg/prod
/// without tocar no código. Defaults mantêm compatibilidade local.
class SupabaseConfig {
  // Pass via: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xwwzsqjgksomniwkvznc.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3d3pzcWpna3NvbW5pd2t2em5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEwMjY1MTIsImV4cCI6MjA1NjYwMjUxMn0.wgqz5pmNzEjZJnhpA6qiWoMKTuIKe2FN3EZHnGwT6Go',
  );

  // Edge Functions base URL (deriva do supabaseUrl por padrão)
  static const String functionsUrl = String.fromEnvironment(
    'SUPABASE_FUNCTIONS_URL',
    defaultValue: 'https://xwwzsqjgksomniwkvznc.supabase.co/functions/v1',
  );
  
  // Aliases for main.dart compatibility
  static String get url => supabaseUrl;
  static String get anonKey => supabaseAnonKey;
}
