import '../datasources/supabase_datasource.dart';
import '../models/notificacao.dart';

/// Repository for Notificacao data
class NotificacaoRepository {
  final SupabaseDatasource _datasource;

  NotificacaoRepository(this._datasource);

  /// Get all notifications for current user/gabinete
  Future<List<Notificacao>> getNotificacoes({
    String? usuarioId,
    int? gabineteId,
    bool? somenteNaoLidas,
  }) async {
    final filters = <String, dynamic>{};

    if (usuarioId != null) {
      filters['usuario'] = usuarioId;
    }
    if (gabineteId != null) {
      filters['gabinete'] = gabineteId;
    }
    if (somenteNaoLidas == true) {
      filters['lida'] = false;
    }

    final data = await _datasource.select(
      table: 'notificacoes',
      eq: filters,
      orderBy: 'created_at',
      ascending: false,
    );

    return data.map((json) => Notificacao.fromJson(json)).toList();
  }

  /// Get count of unread notifications
  Future<int> getNotificacoesNaoLidasCount({
    String? usuarioId,
    int? gabineteId,
  }) async {
    final filters = <String, dynamic>{'lida': false};

    if (usuarioId != null) {
      filters['usuario'] = usuarioId;
    }
    if (gabineteId != null) {
      filters['gabinete'] = gabineteId;
    }

    final data = await _datasource.select(
      table: 'notificacoes',
      eq: filters,
    );

    return data.length;
  }

  /// Mark notification as read
  Future<void> marcarComoLida(int notificacaoId) async {
    await _datasource.update(
      table: 'notificacoes',
      data: {
        'lida': true,
        'lida_em': DateTime.now().toIso8601String(),
      },
      eq: {'id': notificacaoId},
    );
  }

  /// Mark all notifications as read
  Future<void> marcarTodasComoLidas({
    String? usuarioId,
    int? gabineteId,
  }) async {
    final filters = <String, dynamic>{};

    if (usuarioId != null) {
      filters['usuario'] = usuarioId;
    }
    if (gabineteId != null) {
      filters['gabinete'] = gabineteId;
    }

    await _datasource.update(
      table: 'notificacoes',
      data: {
        'lida': true,
        'lida_em': DateTime.now().toIso8601String(),
      },
      eq: filters,
    );
  }

  /// Delete notification
  Future<void> deletarNotificacao(int notificacaoId) async {
    await _datasource.delete(
      table: 'notificacoes',
      eq: {'id': notificacaoId},
    );
  }

  /// Delete all read notifications
  Future<void> limparLidas({
    String? usuarioId,
    int? gabineteId,
  }) async {
    final filters = <String, dynamic>{'lida': true};

    if (usuarioId != null) {
      filters['usuario'] = usuarioId;
    }
    if (gabineteId != null) {
      filters['gabinete'] = gabineteId;
    }

    await _datasource.delete(
      table: 'notificacoes',
      eq: filters,
    );
  }

  /// Create notification
  Future<Notificacao> criarNotificacao({
    String? usuarioId,
    int? gabineteId,
    required TipoNotificacao tipo,
    required PrioridadeNotificacao prioridade,
    required String titulo,
    required String mensagem,
    String? rota,
    Map<String, dynamic>? metadata,
  }) async {
    final data = {
      'usuario': usuarioId,
      'gabinete': gabineteId,
      'tipo': tipo.name,
      'prioridade': prioridade.name,
      'titulo': titulo,
      'mensagem': mensagem,
      'rota': rota,
      'metadata': metadata,
      'lida': false,
    };

    final result = await _datasource.insert(
      table: 'notificacoes',
      data: data,
    );

    return Notificacao.fromJson(result);
  }

  /// Subscribe to realtime notifications
  Stream<List<Notificacao>> watchNotificacoes({
    String? usuarioId,
    int? gabineteId,
  }) {
    // TODO: Implement Supabase Realtime subscription
    // For now, return empty stream
    return Stream.value([]);
  }
}
