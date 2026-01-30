import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// DevLogger for tracking API requests and performance metrics
/// Only active in debug mode
class DevLogger {
  static final DevLogger _instance = DevLogger._internal();
  factory DevLogger() => _instance;
  DevLogger._internal();
  
  /// Get singleton instance
  static DevLogger get instance => _instance;
  
  /// Whether logging is enabled
  bool _enabled = false;
  
  /// Enable or disable logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  /// Check if enabled
  bool get isEnabled => _enabled && kDebugMode;

  // Track requests per route
  final Map<String, List<RequestLog>> _requestsByRoute = {};
  
  // Track current route
  String _currentRoute = '/';
  
  // Track route load times
  final Map<String, Duration> _routeLoadTimes = {};
  
  // Track endpoint call counts
  final Map<String, int> _endpointCounts = {};
  
  // Start time for route
  DateTime? _routeStartTime;

  /// Set current route (call when navigating)
  void setRoute(String route) {
    // Finalize previous route
    if (_routeStartTime != null) {
      _routeLoadTimes[_currentRoute] = DateTime.now().difference(_routeStartTime!);
    }
    
    _currentRoute = route;
    _routeStartTime = DateTime.now();
    _requestsByRoute[route] ??= [];
  }

  /// Log a request
  void logRequest({
    required String endpoint,
    required String method,
    Duration? duration,
    bool cached = false,
    bool deduplicated = false,
  }) {
    if (!kDebugMode) return;

    final log = RequestLog(
      endpoint: endpoint,
      method: method,
      duration: duration ?? Duration.zero,
      cached: cached,
      deduplicated: deduplicated,
      timestamp: DateTime.now(),
    );

    _requestsByRoute[_currentRoute] ??= [];
    _requestsByRoute[_currentRoute]!.add(log);
    
    _endpointCounts[endpoint] = (_endpointCounts[endpoint] ?? 0) + 1;

    developer.log(
      '📡 [${method.toUpperCase()}] $endpoint ${cached ? "(CACHED)" : ""} ${deduplicated ? "(DEDUP)" : ""} - ${duration?.inMilliseconds ?? 0}ms',
      name: 'API',
    );
  }

  /// Get requests count for current route
  int getRequestsForRoute(String route) {
    return _requestsByRoute[route]?.length ?? 0;
  }

  /// Get total load time for route
  Duration? getLoadTimeForRoute(String route) {
    return _routeLoadTimes[route];
  }

  /// Get top endpoints by call count
  List<MapEntry<String, int>> getTopEndpoints({int limit = 10}) {
    final sorted = _endpointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Print summary (call on route change or debug)
  void printSummary() {
    if (!kDebugMode) return;

    developer.log('=' * 60, name: 'DevLogger');
    developer.log('📊 PERFORMANCE SUMMARY', name: 'DevLogger');
    developer.log('=' * 60, name: 'DevLogger');
    
    developer.log('\n📍 Requests por Rota:', name: 'DevLogger');
    for (final entry in _requestsByRoute.entries) {
      final cached = entry.value.where((r) => r.cached).length;
      final dedup = entry.value.where((r) => r.deduplicated).length;
      final loadTime = _routeLoadTimes[entry.key]?.inMilliseconds ?? 0;
      developer.log(
        '  ${entry.key}: ${entry.value.length} requests (cached: $cached, dedup: $dedup) - ${loadTime}ms',
        name: 'DevLogger',
      );
    }
    
    developer.log('\n🔥 Top Endpoints:', name: 'DevLogger');
    for (final entry in getTopEndpoints()) {
      developer.log('  ${entry.key}: ${entry.value}x', name: 'DevLogger');
    }
    
    developer.log('=' * 60, name: 'DevLogger');
  }

  /// Reset all logs
  void reset() {
    _requestsByRoute.clear();
    _routeLoadTimes.clear();
    _endpointCounts.clear();
    _routeStartTime = null;
  }
  
  /// Clear all stats
  void clearStats() {
    reset();
  }
  
  /// Get stats for UI display
  Map<String, dynamic> getStats() {
    int totalRequests = 0;
    for (final requests in _requestsByRoute.values) {
      totalRequests += requests.length;
    }
    
    final routeStats = <String, Map<String, dynamic>>{};
    for (final entry in _requestsByRoute.entries) {
      routeStats[entry.key] = {
        'requests': entry.value.length,
        'loadTime': _routeLoadTimes[entry.key]?.inMilliseconds ?? 0,
      };
    }
    
    return {
      'totalRequests': totalRequests,
      'topEndpoints': Map.fromEntries(getTopEndpoints()),
      'routeStats': routeStats,
    };
  }
}

class RequestLog {
  final String endpoint;
  final String method;
  final Duration duration;
  final bool cached;
  final bool deduplicated;
  final DateTime timestamp;

  RequestLog({
    required this.endpoint,
    required this.method,
    required this.duration,
    required this.cached,
    required this.deduplicated,
    required this.timestamp,
  });
}
