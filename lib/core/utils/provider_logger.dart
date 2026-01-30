import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_reporter.dart';

/// Observa mudanças de providers e centraliza erros do Riverpod.
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Apenas erros: evita ruído de state updates normais.
    if (newValue is AsyncError) {
      ErrorReporter.report(newValue.error, newValue.stackTrace);
    }
  }
}
