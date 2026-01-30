import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/dev_logger.dart';
import '../../core/errors/exceptions.dart';

/// Single point of access to Supabase
/// Handles all database queries with logging and error handling
class SupabaseDatasource {
  final SupabaseClient _client;
  final DevLogger _logger = DevLogger();
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const int _maxRetries = 2;

  SupabaseDatasource(this._client);

  /// Get Supabase client instance
  SupabaseClient get client => _client;

  /// Current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Execute a SELECT query with logging
  Future<List<Map<String, dynamic>>> select({
    required String table,
    String columns = '*',
    Map<String, dynamic>? eq,
    Map<String, dynamic>? neq,
    String? or,
    String? contains,
    String? containsValue,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await _withResilience<List<Map<String, dynamic>>>(
        'select $table',
        () async {
          // Build the query step by step
          PostgrestFilterBuilder<List<Map<String, dynamic>>> filterQuery =
              _client.from(table).select(columns);

          // Apply filters
          if (eq != null) {
            for (final entry in eq.entries) {
              if (entry.value != null) {
                filterQuery = filterQuery.eq(entry.key, entry.value);
              }
            }
          }

          if (neq != null) {
            for (final entry in neq.entries) {
              if (entry.value != null) {
                filterQuery = filterQuery.neq(entry.key, entry.value);
              }
            }
          }

          if (or != null) {
            filterQuery = filterQuery.or(or);
          }

          if (contains != null && containsValue != null) {
            filterQuery = filterQuery.contains(contains, containsValue);
          }

          // Apply ordering, pagination - these return a transform builder
          PostgrestTransformBuilder<List<Map<String, dynamic>>> transformQuery =
              filterQuery;

          if (orderBy != null) {
            transformQuery = transformQuery.order(orderBy, ascending: ascending);
          }

          if (limit != null) {
            transformQuery = transformQuery.limit(limit);
          }

          if (offset != null) {
            transformQuery =
                transformQuery.range(offset, offset + (limit ?? 20) - 1);
          }

          final result = await transformQuery;
          return List<Map<String, dynamic>>.from(result);
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (SELECT)',
        method: 'GET',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Execute a SELECT query for a single row
  Future<Map<String, dynamic>?> selectSingle({
    required String table,
    String columns = '*',
    required Map<String, dynamic> eq,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await _withResilience<Map<String, dynamic>?>(
        'select single $table',
        () async {
          var query = _client.from(table).select(columns);

          for (final entry in eq.entries) {
            if (entry.value != null) {
              query = query.eq(entry.key, entry.value);
            }
          }

          return await query.limit(1).maybeSingle();
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (SELECT SINGLE)',
        method: 'GET',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Execute a SELECT query with IN clause
  Future<List<Map<String, dynamic>>> selectIn({
    required String table,
    String columns = '*',
    required String column,
    required List<dynamic> values,
  }) async {
    if (values.isEmpty) return [];
    
    final stopwatch = Stopwatch()..start();
    
    try {
      return await _withResilience<List<Map<String, dynamic>>>(
        'select in $table',
        () async {
          final result = await _client
              .from(table)
              .select(columns)
              .inFilter(column, values);
          return List<Map<String, dynamic>>.from(result);
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (SELECT IN)',
        method: 'GET',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Execute an INSERT query
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      return await _withResilience<Map<String, dynamic>>(
        'insert $table',
        () async {
          final result = await _client
              .from(table)
              .insert(data)
              .select()
              .single();
          return result;
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (INSERT)',
        method: 'POST',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Execute an UPDATE query
  Future<List<Map<String, dynamic>>> update({
    required String table,
    required Map<String, dynamic> data,
    required Map<String, dynamic> eq,
    bool returnData = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      return await _withResilience<List<Map<String, dynamic>>>(
        'update $table',
        () async {
          // Build the query with eq filters directly
          final filteredTable = _client.from(table);

          // Build update with proper chaining
          PostgrestFilterBuilder updateQuery = filteredTable.update(data);

          for (final entry in eq.entries) {
            if (entry.value != null) {
              updateQuery = updateQuery.eq(entry.key, entry.value);
            }
          }

          if (returnData) {
            final result = await updateQuery.select();
            return List<Map<String, dynamic>>.from(result);
          }

          await updateQuery;
          return [];
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (UPDATE)',
        method: 'PATCH',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Execute a DELETE query
  Future<void> delete({
    required String table,
    required Map<String, dynamic> eq,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await _withResilience<void>(
        'delete $table',
        () async {
          var query = _client.from(table).delete();

          for (final entry in eq.entries) {
            if (entry.value != null) {
              query = query.eq(entry.key, entry.value);
            }
          }

          await query;
        },
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: '$table (DELETE)',
        method: 'DELETE',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Call an RPC function
  Future<dynamic> rpc({
    required String functionName,
    Map<String, dynamic>? params,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      return await _withResilience<dynamic>(
        'rpc $functionName',
        () => _client.rpc(functionName, params: params),
      );
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: 'rpc:$functionName',
        method: 'POST',
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Call an Edge Function
  Future<Map<String, dynamic>> edgeFunction({
    required String functionName,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await _withResilience<FunctionResponse>(
        'edge $functionName',
        () => _client.functions.invoke(
          functionName,
          body: body,
          headers: headers,
        ),
      );
      
      if (response.status >= 400) {
        throw ServerException(
          'Edge function error',
          statusCode: response.status,
        );
      }
      
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to call edge function $functionName: $e');
    } finally {
      stopwatch.stop();
      _logger.logRequest(
        endpoint: 'edge:$functionName',
        method: 'POST',
        duration: stopwatch.elapsed,
      );
    }
  }

  // ========= Resiliência / Timeout =========
  Future<T> _withResilience<T>(
    String label,
    Future<T> Function() action,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await action().timeout(_defaultTimeout);
      } on TimeoutException catch (e) {
        if (attempt >= _maxRetries) {
          throw ServerException('Timeout em $label: ${e.message}');
        }
        attempt++;
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on PostgrestException catch (e) {
        final code = int.tryParse(e.code ?? '');
        final isServer = code != null && code >= 500;
        if (isServer && attempt < _maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 200 * attempt));
          continue;
        }
        throw ServerException('Postgrest error em $label: ${e.message}',
            statusCode: code);
      }
    }
  }
}
