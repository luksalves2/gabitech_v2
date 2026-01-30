import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core_providers.dart';
import '../data/services/uazapi_service.dart';

/// Lista de transmissões do gabinete atual
final transmissoesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repo = ref.watch(transmissaoRepositoryProvider);
  return repo.getByGabinete(gabinete.id);
});

class TransmissoesMetrics {
  final int total;
  final int agendadas;
  final int enviando;
  final int finalizadas;
  final int rascunhos;
  final int impactados;

  const TransmissoesMetrics({
    required this.total,
    required this.agendadas,
    required this.enviando,
    required this.finalizadas,
    required this.rascunhos,
    required this.impactados,
  });
}

final transmissoesMetricsProvider = Provider<TransmissoesMetrics>((ref) {
  final transmissoesAsync = ref.watch(transmissoesProvider);
  return transmissoesAsync.when(
    data: (list) {
      bool isStatus(Map<String, dynamic> c, List<String> values) {
        final raw = (c['status'] ?? '').toString().toLowerCase();
        return values.any((v) => raw == v.toLowerCase());
      }

      int countStatus(List<String> values) =>
          list.where((c) => isStatus(c, values)).length;
      final total = list.length;
      return TransmissoesMetrics(
        total: total,
        agendadas: countStatus(['Agendada', 'Agendado']),
        enviando: countStatus(['Enviando']),
        finalizadas: countStatus(['Enviado', 'Enviada']),
        rascunhos: countStatus(['Rascunho']),
        impactados: list.fold<int>(
          0,
          (s, c) => s + (c['qtd'] as int? ?? 0),
        ),
      );
    },
    loading: () => const TransmissoesMetrics(
      total: 0,
      agendadas: 0,
      enviando: 0,
      finalizadas: 0,
      rascunhos: 0,
      impactados: 0,
    ),
    error: (_, __) => const TransmissoesMetrics(
      total: 0,
      agendadas: 0,
      enviando: 0,
      finalizadas: 0,
      rascunhos: 0,
      impactados: 0,
    ),
  );
});

/// Campanhas da API Uazapi (listfolders)
/// Também sincroniza os status com a tabela transmissoes
final campanhasApiProvider =
    FutureProvider<List<UazapiFolderCampaign>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null || gabinete.token == null) return [];

  final service = ref.watch(uazapiServiceProvider);
  final result =
      await service.listarCampanhas(instanceToken: gabinete.token!);

  if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
    // Sincronizar status das campanhas com a tabela transmissoes
    final repo = ref.read(transmissaoRepositoryProvider);
    final campanhasParaSync = result.data!.map((c) => {
      'id': c.id,
      'status': c.status,
      'logSuccess': c.logSuccess,
      'logFailed': c.logFailed,
      'logTotal': c.logTotal,
      'logDelivered': c.logDelivered,
      'logPlayed': c.logPlayed,
      'logRead': c.logRead,
    }).toList();

    try {
      await repo.syncBulkFromApi(campanhasParaSync);
      // Invalidar provider de transmissões para recarregar com status atualizado
      ref.invalidate(transmissoesProvider);
    } catch (_) {
      // Silenciar erros de sync para não bloquear a exibição
    }

    return result.data!;
  }

  return [];
});

/// Provider para buscar estatísticas de envios de todas as transmissões
/// Retorna Map<transmissaoId, {total, enviados, falhas, pendentes}>
final transmissoesEnviosStatsProvider =
    FutureProvider<Map<int, Map<String, int>>>((ref) async {
  final transmissoesAsync = await ref.watch(transmissoesProvider.future);
  if (transmissoesAsync.isEmpty) return {};

  final ids = transmissoesAsync
      .map((t) => t['id'] as int?)
      .where((id) => id != null)
      .cast<int>()
      .toList();

  if (ids.isEmpty) return {};

  final repo = ref.watch(transmissaoRepositoryProvider);
  return repo.getEnviosStatsBulk(ids);
});

/// Função para agendar verificação automática do status de uma campanha
/// Chama a API após [delaySeconds] segundos e sincroniza o status
Future<void> agendarVerificacaoCampanha({
  required WidgetRef ref,
  required int transmissaoId,
  required String idCampanha,
  required String instanceToken,
  int delaySeconds = 60,
}) async {
  debugPrint('[SYNC] Agendando verificação da campanha $idCampanha em $delaySeconds segundos');

  await Future.delayed(Duration(seconds: delaySeconds));

  debugPrint('[SYNC] Iniciando verificação da campanha $idCampanha');

  try {
    final service = ref.read(uazapiServiceProvider);
    final result = await service.buscarCampanhaPorFolder(
      instanceToken: instanceToken,
      folderId: idCampanha,
    );

    if (result.isSuccess && result.data != null) {
      final campanha = result.data!;
      debugPrint('[SYNC] Campanha encontrada: status=${campanha.status}, success=${campanha.logSuccess}, failed=${campanha.logFailed}');

      final repo = ref.read(transmissaoRepositoryProvider);
      await repo.syncTransmissaoFromApiStats(
        transmissaoId: transmissaoId,
        idCampanha: idCampanha,
        statusApi: campanha.status ?? 'unknown',
        logSuccess: campanha.logSuccess,
        logFailed: campanha.logFailed,
        logTotal: campanha.logTotal,
        logDelivered: campanha.logDelivered,
        logPlayed: campanha.logPlayed,
        logRead: campanha.logRead,
      );

      // Invalidar providers para recarregar dados atualizados
      ref.invalidate(transmissoesProvider);
      ref.invalidate(transmissoesEnviosStatsProvider);

      debugPrint('[SYNC] Sincronização concluída com sucesso');
    } else {
      debugPrint('[SYNC] Campanha não encontrada na API: ${result.error}');
    }
  } catch (e, st) {
    debugPrint('[SYNC] ERRO na verificação: $e');
    debugPrint('[SYNC] StackTrace: $st');
  }
}

/// Versão sem WidgetRef (para uso fora de widgets, com Ref diretamente)
Future<void> agendarVerificacaoCampanhaRef({
  required Ref ref,
  required int transmissaoId,
  required String idCampanha,
  required String instanceToken,
  int delaySeconds = 60,
}) async {
  debugPrint('[SYNC] Agendando verificação da campanha $idCampanha em $delaySeconds segundos');

  await Future.delayed(Duration(seconds: delaySeconds));

  debugPrint('[SYNC] Iniciando verificação da campanha $idCampanha');

  try {
    final service = ref.read(uazapiServiceProvider);
    final result = await service.buscarCampanhaPorFolder(
      instanceToken: instanceToken,
      folderId: idCampanha,
    );

    if (result.isSuccess && result.data != null) {
      final campanha = result.data!;
      debugPrint('[SYNC] Campanha encontrada: status=${campanha.status}, success=${campanha.logSuccess}, failed=${campanha.logFailed}');

      final repo = ref.read(transmissaoRepositoryProvider);
      await repo.syncTransmissaoFromApiStats(
        transmissaoId: transmissaoId,
        idCampanha: idCampanha,
        statusApi: campanha.status ?? 'unknown',
        logSuccess: campanha.logSuccess,
        logFailed: campanha.logFailed,
        logTotal: campanha.logTotal,
        logDelivered: campanha.logDelivered,
        logPlayed: campanha.logPlayed,
        logRead: campanha.logRead,
      );

      // Invalidar providers para recarregar dados atualizados
      ref.invalidate(transmissoesProvider);
      ref.invalidate(transmissoesEnviosStatsProvider);

      debugPrint('[SYNC] Sincronização concluída com sucesso');
    } else {
      debugPrint('[SYNC] Campanha não encontrada na API: ${result.error}');
    }
  } catch (e, st) {
    debugPrint('[SYNC] ERRO na verificação: $e');
    debugPrint('[SYNC] StackTrace: $st');
  }
}
