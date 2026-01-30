import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/utils/dev_logger.dart';
import 'core/utils/error_reporter.dart';
import 'core/utils/provider_logger.dart';
import 'router.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/notification_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: kDebugMode,
  );
  
  // Enable dev logging in debug mode
  if (kDebugMode) {
    DevLogger.instance.setEnabled(true);
  }
  
  // Global error guards
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.report(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorReporter.report(error, stack);
    return true;
  };
  
  runZonedGuarded(
    () => runApp(
      const ProviderScope(
        observers: [AppProviderObserver()],
        child: GabitechApp(),
      ),
    ),
    (error, stack) => ErrorReporter.report(error, stack),
  );
}

class GabitechApp extends ConsumerWidget {
  const GabitechApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Gabitech',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // Wrap with notification toast container
        Widget content = NotificationToastContainer(
          child: child ?? const SizedBox.shrink(),
        );

        // Add dev overlay in debug mode
        if (kDebugMode) {
          return Stack(
            children: [
              content,
              const Positioned(
                bottom: 16,
                right: 16,
                child: _DevLoggerButton(),
              ),
            ],
          );
        }
        return content;
      },
    );
  }
}

/// Dev logger button for debugging
class _DevLoggerButton extends StatelessWidget {
  const _DevLoggerButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const _DevLoggerSheet(),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(seconds: 1),
                  (_) => DevLogger.instance.getStats()['totalRequests'] as int,
                ),
                builder: (context, snapshot) {
                  return Text(
                    '${snapshot.data ?? 0} reqs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevLoggerSheet extends StatelessWidget {
  const _DevLoggerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final stats = DevLogger.instance.getStats();
        final topEndpoints = stats['topEndpoints'] as Map<String, int>;
        final routeStats = stats['routeStats'] as Map<String, Map<String, dynamic>>;
        
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Dev Logger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        DevLogger.instance.clearStats();
                        Navigator.pop(context);
                      },
                      tooltip: 'Limpar',
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall stats
                      _StatCard(
                        title: 'Total de Requests',
                        value: '${stats['totalRequests']}',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      
                      // Top endpoints
                      const Text(
                        'Top Endpoints',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...topEndpoints.entries.take(10).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              '${e.value}x',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                      
                      const SizedBox(height: 20),
                      
                      // Route stats
                      const Text(
                        'Stats por Rota',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...routeStats.entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Requests: ${e.value['requests']}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Tempo: ${e.value['loadTime']}ms',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
