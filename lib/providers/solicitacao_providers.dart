import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/solicitacao.dart';
import 'core_providers.dart';

/// Provider for solicitações grouped by status (for Kanban)
final solicitacoesKanbanProvider = FutureProvider.autoDispose
    .family<Map<String, List<Solicitacao>>, SolicitacoesParams>((ref, params) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) {
    return <String, List<Solicitacao>>{};
  }
  
  final repository = ref.watch(solicitacaoRepositoryProvider);
  return repository.getByGabineteGroupedByStatus(
    gabinete.id,
    categoriaId: params.categoriaId,
    searchTerm: params.searchTerm,
  );
});

/// Provider for solicitações as flat list (for list view)
final solicitacoesListProvider = FutureProvider.autoDispose
    .family<List<Solicitacao>, SolicitacoesParams>((ref, params) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];
  
  final repository = ref.watch(solicitacaoRepositoryProvider);
  return repository.getByGabinete(
    gabinete.id,
    categoriaId: params.categoriaId,
    searchTerm: params.searchTerm,
    status: params.status,
  );
});

/// Provider for single solicitação
final solicitacaoProvider = FutureProvider.autoDispose
    .family<Solicitacao?, int>((ref, id) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  final repository = ref.watch(solicitacaoRepositoryProvider);
  return repository.getById(id, gabineteId: gabinete?.id);
});

/// Provider for solicitações of a specific cidadão
final solicitacoesByCidadaoProvider = FutureProvider.autoDispose
    .family<List<Solicitacao>, int>((ref, cidadaoId) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  final repository = ref.watch(solicitacaoRepositoryProvider);
  return repository.getByCidadao(cidadaoId, gabineteId: gabinete?.id);
});

/// State notifier for solicitação operations
class SolicitacaoNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SolicitacaoNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Solicitacao?> create({
    required int cidadaoId,
    required String titulo,
    String? descricao,
    String? resumo,
    String? prioridade,
    int? categoriaId,
    String? categoria,
    String? prazo,
    String? acessor,
    String? nomeAcessor,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      if (gabinete == null) {
        state = AsyncValue.error('Gabinete não encontrado', StackTrace.current);
        return null;
      }

      final repository = _ref.read(solicitacaoRepositoryProvider);
      final solicitacao = await repository.create(
        gabineteId: gabinete.id,
        cidadaoId: cidadaoId,
        titulo: titulo,
        descricao: descricao,
        resumo: resumo,
        prioridade: prioridade,
        categoriaId: categoriaId,
        categoria: categoria,
        prazo: prazo,
        acessor: acessor,
        nomeAcessor: nomeAcessor,
      );

      // Invalidate the kanban provider to refresh the list
      _ref.invalidate(solicitacoesKanbanProvider);
      _ref.invalidate(solicitacoesListProvider);
      
      state = const AsyncValue.data(null);
      return solicitacao;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateStatus(int id, String status) async {
    state = const AsyncValue.loading();
    
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      final repository = _ref.read(solicitacaoRepositoryProvider);
      await repository.updateStatus(
        id: id,
        status: status,
        gabineteId: gabinete?.id,
      );
      
      // Invalidate providers to refresh
      _ref.invalidate(solicitacoesKanbanProvider);
      _ref.invalidate(solicitacoesListProvider);
      _ref.invalidate(solicitacaoProvider(id));
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(int id) async {
    state = const AsyncValue.loading();
    
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      final repository = _ref.read(solicitacaoRepositoryProvider);
      await repository.delete(id, gabineteId: gabinete?.id);
      
      // Invalidate providers
      _ref.invalidate(solicitacoesKanbanProvider);
      _ref.invalidate(solicitacoesListProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final solicitacaoNotifierProvider =
    StateNotifierProvider<SolicitacaoNotifier, AsyncValue<void>>((ref) {
  return SolicitacaoNotifier(ref);
});

/// Parameters for solicitações provider
class SolicitacoesParams {
  final int? categoriaId;
  final String? searchTerm;
  final String? status;

  const SolicitacoesParams({
    this.categoriaId,
    this.searchTerm,
    this.status,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SolicitacoesParams &&
        other.categoriaId == categoriaId &&
        other.searchTerm == searchTerm &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(categoriaId, searchTerm, status);
}
