import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/dashboard_data.dart';
import 'core_providers.dart';

/// Dashboard data provider with auto-refresh
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return const DashboardData();

  final repository = ref.watch(dashboardRepositoryProvider);
  return repository.getDashboardData(gabinete.id);
});

/// Force refresh dashboard
void refreshDashboard(WidgetRef ref) {
  ref.read(dashboardRepositoryProvider).clearCache();
  ref.invalidate(dashboardProvider);
}
