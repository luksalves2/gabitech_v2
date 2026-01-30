import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/usuario.dart';
import 'core_providers.dart';

/// Provider for assessores list
final assessoresProvider = FutureProvider<List<Usuario>>((ref) async {
  final currentGabinete = await ref.watch(currentGabineteProvider.future);
  if (currentGabinete == null) return [];

  final repository = ref.watch(usuarioRepositoryProvider);
  return repository.getAcessoresByGabinete(currentGabinete.id);
});

/// Provider for assessores metrics
final assessoresMetricsProvider = Provider<Map<String, int>>((ref) {
  final assessoresAsync = ref.watch(assessoresProvider);

  return assessoresAsync.when(
    data: (assessores) {
      final total = assessores.length;
      final ativos = assessores.where((a) => a.isAtivo == true).length;
      return {
        'total': total,
        'ativos': ativos,
        'inativos': total - ativos,
      };
    },
    loading: () => {'total': 0, 'ativos': 0, 'inativos': 0},
    error: (_, __) => {'total': 0, 'ativos': 0, 'inativos': 0},
  );
});

/// Notifier for managing assessor operations
class AssessorNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AssessorNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> createAssessor({
    required String email,
    required String password,
    required String nome,
    required String telefone,
    required String cargo,
    bool dashboard = false,
    bool solicitacoes = false,
    bool cidadaos = false,
    bool atividades = false,
    bool transmissoes = false,
    bool mensagens = false,
    bool acessores = false,
  }) async {
    state = const AsyncValue.loading();

    try {
      final currentGabinete = await _ref.read(currentGabineteProvider.future);
      if (currentGabinete == null) {
        throw Exception('Gabinete não encontrado');
      }

      final repository = _ref.read(usuarioRepositoryProvider);
      await repository.createAcessor(
        email: email,
        password: password,
        nome: nome,
        telefone: telefone,
        cargo: cargo,
        gabineteId: currentGabinete.id,
        dashboard: dashboard,
        solicitacoes: solicitacoes,
        cidadaos: cidadaos,
        atividades: atividades,
        transmissoes: transmissoes,
        mensagens: mensagens,
        acessores: acessores,
      );

      // Refresh assessores list
      _ref.invalidate(assessoresProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateAssessor({
    required String uuid,
    String? nome,
    String? telefone,
    String? cargo,
    bool? status,
    bool? dashboard,
    bool? solicitacoes,
    bool? cidadaos,
    bool? atividades,
    bool? transmissoes,
    bool? mensagens,
    bool? acessores,
  }) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(usuarioRepositoryProvider);
      await repository.updateAcessorPermissions(
        uuid: uuid,
        nome: nome,
        telefone: telefone,
        cargo: cargo,
        status: status,
        dashboard: dashboard,
        solicitacoes: solicitacoes,
        cidadaos: cidadaos,
        atividades: atividades,
        transmissoes: transmissoes,
        mensagens: mensagens,
        acessores: acessores,
      );

      // Refresh assessores list
      _ref.invalidate(assessoresProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteAssessor(String uuid) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(usuarioRepositoryProvider);
      final success = await repository.deleteAcessor(uuid);

      if (!success) {
        throw Exception('Falha ao excluir assessor');
      }

      // Refresh assessores list
      _ref.invalidate(assessoresProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final assessorNotifierProvider = StateNotifierProvider<AssessorNotifier, AsyncValue<void>>((ref) {
  return AssessorNotifier(ref);
});
