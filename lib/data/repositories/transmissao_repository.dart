import 'package:flutter/foundation.dart';
import '../datasources/supabase_datasource.dart';

/// Repository for Transmissao (campanhas) data
class TransmissaoRepository {
  final SupabaseDatasource _datasource;

  TransmissaoRepository(this._datasource);

  Future<List<Map<String, dynamic>>> getByGabinete(int gabineteId) async {
    return _datasource.select(
      table: 'transmissoes',
      eq: {'gabinete': gabineteId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<Map<String, dynamic>> createTransmissao({
    required int gabineteId,
    required String idCampanha,
    required String titulo,
    required String mensagem,
    String? arquivo,
    required String status,
    required String data,
    required String hora,
    int? qtd,
    int? dataAgendamento,
    String? genero,
    List<String>? perfil,
    List<String>? categorias,
    List<String>? bairros,
  }) async {
    final payload = <String, dynamic>{
      'gabinete': gabineteId,
      'id_campanha': idCampanha,
      'titulo': titulo,
      'mensagem': mensagem,
      'arquivo': arquivo,
      'status': status,
      'data': data,
      'hora': hora,
      'qtd': qtd,
      'data_agendamento': dataAgendamento,
      'genero': genero,
      'perfil': perfil,
      'categorias': categorias,
      'bairros': bairros,
    };

    payload.removeWhere((key, value) => value == null);

    debugPrint('[REPO] createTransmissao payload: $payload');
    try {
      final result = await _datasource.insert(
        table: 'transmissoes',
        data: payload,
      );
      debugPrint('[REPO] createTransmissao resultado: $result');
      return result;
    } catch (e, st) {
      debugPrint('[REPO] ERRO createTransmissao: $e');
      debugPrint('[REPO] StackTrace: $st');
      rethrow;
    }
  }

  Future<void> updateStatus({
    required int id,
    required String status,
  }) async {
    debugPrint('[REPO] updateStatus: id=$id, status=$status');
    try {
      await _datasource.update(
        table: 'transmissoes',
        data: {'status': status},
        eq: {'id': id},
      );
      debugPrint('[REPO] updateStatus concluído');
    } catch (e, st) {
      debugPrint('[REPO] ERRO updateStatus: $e');
      debugPrint('[REPO] StackTrace: $st');
      rethrow;
    }
  }

  /// Atualiza status e estatísticas de uma transmissão pelo id_campanha
  Future<void> syncFromApi({
    required String idCampanha,
    required String status,
    int? logSuccess,
    int? logFailed,
    int? logTotal,
    int? logDelivered,
    int? logPlayed,
    int? logRead,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'api_updated_at': DateTime.now().toIso8601String(),
    };

    // Adicionar campos de log se fornecidos
    if (logSuccess != null) data['log_success'] = logSuccess;
    if (logFailed != null) data['log_failed'] = logFailed;
    if (logTotal != null) data['log_total'] = logTotal;
    if (logDelivered != null) data['log_delivered'] = logDelivered;
    if (logPlayed != null) data['log_played'] = logPlayed;
    if (logRead != null) data['log_read'] = logRead;

    debugPrint('[REPO] syncFromApi: idCampanha=$idCampanha, data=$data');

    await _datasource.update(
      table: 'transmissoes',
      data: data,
      eq: {'id_campanha': idCampanha},
    );
  }

  /// Sincroniza múltiplas transmissões com os dados da API
  Future<void> syncBulkFromApi(List<Map<String, dynamic>> campanhasApi) async {
    for (final campanha in campanhasApi) {
      final idCampanha = campanha['id'] as String?;
      final statusApi = campanha['status'] as String?;

      if (idCampanha == null || statusApi == null) continue;

      // Mapear status da API para status do sistema
      String statusSistema;
      switch (statusApi.toLowerCase()) {
        case 'done':
        case 'finished':
        case 'completed':
          statusSistema = 'Enviado';
          break;
        case 'running':
        case 'sending':
          statusSistema = 'Enviando';
          break;
        case 'scheduled':
        case 'pending':
          statusSistema = 'Agendada';
          break;
        case 'failed':
        case 'error':
          statusSistema = 'Falha';
          break;
        case 'paused':
          statusSistema = 'Pausado';
          break;
        default:
          statusSistema = statusApi;
      }

      await syncFromApi(
        idCampanha: idCampanha,
        status: statusSistema,
        logSuccess: campanha['logSuccess'] as int?,
        logFailed: campanha['logFailed'] as int?,
        logTotal: campanha['logTotal'] as int?,
        logDelivered: campanha['logDelivered'] as int?,
        logPlayed: campanha['logPlayed'] as int?,
        logRead: campanha['logRead'] as int?,
      );
    }
  }

  Future<void> createEnviosBulk({
    required int transmissaoId,
    required List<Map<String, dynamic>> envios,
  }) async {
    debugPrint('[REPO] createEnviosBulk: transmissaoId=$transmissaoId, envios.length=${envios.length}');
    if (envios.isEmpty) {
      debugPrint('[REPO] createEnviosBulk: lista vazia, retornando');
      return;
    }
    final payload = envios.map((e) {
      return {
        'transmissao_id': transmissaoId,
        'cidadao_id': e['cidadao_id'],
        'telefone': e['telefone'],
        'status': e['status'] ?? 'pendente',
      };
    }).toList();

    debugPrint('[REPO] createEnviosBulk payload (primeiro item): ${payload.isNotEmpty ? payload.first : 'vazio'}');
    try {
      await _datasource.client.from('transmissao_envios').insert(payload);
      debugPrint('[REPO] createEnviosBulk: inserção concluída com sucesso');
    } catch (e, st) {
      debugPrint('[REPO] ERRO createEnviosBulk: $e');
      debugPrint('[REPO] StackTrace: $st');
      rethrow;
    }
  }

  Future<List<String>> getEnviosTelefones(int transmissaoId) async {
    final data = await _datasource.client
        .from('transmissao_envios')
        .select('telefone')
        .eq('transmissao_id', transmissaoId);
    return (data as List<dynamic>)
        .map((e) => e['telefone'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Sincroniza uma transmissão com os dados da API (por id_campanha/folder)
  /// Atualiza status e distribui os status dos envios com base nas estatísticas da API
  Future<void> syncTransmissaoFromApiStats({
    required int transmissaoId,
    required String idCampanha,
    required String statusApi,
    int? logSuccess,
    int? logFailed,
    int? logTotal,
    int? logDelivered,
    int? logPlayed,
    int? logRead,
  }) async {
    debugPrint('[REPO] syncTransmissaoFromApiStats: transmissaoId=$transmissaoId, idCampanha=$idCampanha, statusApi=$statusApi');
    debugPrint('[REPO] Stats: logSuccess=$logSuccess, logFailed=$logFailed, logTotal=$logTotal, logDelivered=$logDelivered, logPlayed=$logPlayed, logRead=$logRead');

    // Mapear status da API para status do sistema
    String statusSistema;
    switch (statusApi.toLowerCase()) {
      case 'done':
      case 'finished':
      case 'completed':
        statusSistema = 'Enviado';
        break;
      case 'running':
      case 'sending':
        statusSistema = 'Enviando';
        break;
      case 'scheduled':
      case 'pending':
        statusSistema = 'Agendada';
        break;
      case 'failed':
      case 'error':
        statusSistema = 'Falha';
        break;
      case 'paused':
        statusSistema = 'Pausado';
        break;
      default:
        statusSistema = statusApi;
    }

    // Atualizar status e logs da transmissão
    try {
      final data = <String, dynamic>{
        'status': statusSistema,
        'api_updated_at': DateTime.now().toIso8601String(),
      };
      if (logSuccess != null) data['log_success'] = logSuccess;
      if (logFailed != null) data['log_failed'] = logFailed;
      if (logTotal != null) data['log_total'] = logTotal;
      if (logDelivered != null) data['log_delivered'] = logDelivered;
      if (logPlayed != null) data['log_played'] = logPlayed;
      if (logRead != null) data['log_read'] = logRead;

      await _datasource.update(
        table: 'transmissoes',
        data: data,
        eq: {'id': transmissaoId},
      );
      debugPrint('[REPO] Transmissão atualizada com logs: $data');
    } catch (e) {
      debugPrint('[REPO] ERRO ao atualizar status da transmissão: $e');
    }

    // Se temos estatísticas da API, atualizar os envios
    if (logSuccess != null || logFailed != null) {
      try {
        // Buscar todos os envios pendentes desta transmissão
        final enviosPendentes = await _datasource.client
            .from('transmissao_envios')
            .select('id, status')
            .eq('transmissao_id', transmissaoId)
            .eq('status', 'pendente');

        final lista = enviosPendentes as List<dynamic>;
        debugPrint('[REPO] Envios pendentes encontrados: ${lista.length}');

        if (lista.isEmpty) return;

        final success = logSuccess ?? 0;
        final failed = logFailed ?? 0;

        // Marcar os primeiros 'success' como 'enviado'
        int marcadosOk = 0;
        int marcadosFalha = 0;

        for (final envio in lista) {
          final envioId = envio['id'] as int;
          String novoStatus;

          if (marcadosOk < success) {
            novoStatus = 'enviado';
            marcadosOk++;
          } else if (marcadosFalha < failed) {
            novoStatus = 'falha';
            marcadosFalha++;
          } else {
            break; // Não há mais status para distribuir
          }

          await _datasource.client
              .from('transmissao_envios')
              .update({'status': novoStatus})
              .eq('id', envioId);
        }

        debugPrint('[REPO] Envios atualizados: $marcadosOk enviados, $marcadosFalha falhas');
      } catch (e, st) {
        debugPrint('[REPO] ERRO ao atualizar envios: $e');
        debugPrint('[REPO] StackTrace: $st');
      }
    }
  }

  /// Busca transmissão pelo id_campanha (folder da API)
  Future<Map<String, dynamic>?> getByIdCampanha(String idCampanha) async {
    try {
      final data = await _datasource.client
          .from('transmissoes')
          .select()
          .eq('id_campanha', idCampanha)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[REPO] ERRO getByIdCampanha: $e');
      return null;
    }
  }

  /// Busca estatísticas de envios para uma transmissão
  /// Retorna {total, enviados, falhas, pendentes}
  Future<Map<String, int>> getEnviosStats(int transmissaoId) async {
    final data = await _datasource.client
        .from('transmissao_envios')
        .select('status')
        .eq('transmissao_id', transmissaoId);

    final list = data as List<dynamic>;
    int enviados = 0;
    int falhas = 0;
    int pendentes = 0;

    for (final item in list) {
      final status = (item['status'] as String? ?? '').toLowerCase();
      if (status == 'enviado' || status == 'ok' || status == 'success') {
        enviados++;
      } else if (status == 'falha' || status == 'erro' || status == 'failed') {
        falhas++;
      } else {
        pendentes++;
      }
    }

    return {
      'total': list.length,
      'enviados': enviados,
      'falhas': falhas,
      'pendentes': pendentes,
    };
  }

  /// Busca estatísticas de envios para várias transmissões de uma vez
  Future<Map<int, Map<String, int>>> getEnviosStatsBulk(List<int> transmissaoIds) async {
    if (transmissaoIds.isEmpty) return {};

    final data = await _datasource.client
        .from('transmissao_envios')
        .select('transmissao_id, status')
        .inFilter('transmissao_id', transmissaoIds);

    final result = <int, Map<String, int>>{};

    // Inicializar todos os IDs
    for (final id in transmissaoIds) {
      result[id] = {'total': 0, 'enviados': 0, 'falhas': 0, 'pendentes': 0};
    }

    for (final item in data as List<dynamic>) {
      final transmissaoId = item['transmissao_id'] as int;
      final status = (item['status'] as String? ?? '').toLowerCase();

      result[transmissaoId]!['total'] = result[transmissaoId]!['total']! + 1;

      if (status == 'enviado' || status == 'ok' || status == 'success') {
        result[transmissaoId]!['enviados'] = result[transmissaoId]!['enviados']! + 1;
      } else if (status == 'falha' || status == 'erro' || status == 'failed') {
        result[transmissaoId]!['falhas'] = result[transmissaoId]!['falhas']! + 1;
      } else {
        result[transmissaoId]!['pendentes'] = result[transmissaoId]!['pendentes']! + 1;
      }
    }

    return result;
  }
}
