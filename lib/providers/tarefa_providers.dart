import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/tarefa.dart';
import '../data/models/categoria_tarefa.dart';
import '../data/models/nota_tarefa.dart';
import '../data/repositories/tarefa_repository.dart';
import 'core_providers.dart';

/// Renomeia o arquivo para nota.dart mas mantém compatibilidade
export '../data/models/nota_tarefa.dart';

/// Provider for TarefaRepository
final tarefaRepositoryProvider = Provider<TarefaRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return TarefaRepository(datasource);
});

/// Provider for categorias_tarefas by gabinete
final categoriasTarefasProvider = FutureProvider.autoDispose<List<CategoriaTarefa>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];
  
  final datasource = ref.watch(supabaseDatasourceProvider);
  final data = await datasource.select(
    table: 'categorias_tarefas',
    columns: '*',
    eq: {'gabinete': gabinete.id},
    orderBy: 'nome',
    ascending: true,
  );
  
  return data.map((json) => CategoriaTarefa.fromJson(json)).toList();
});

/// Provider for atividades by solicitacao
final atividadesBySolicitacaoProvider = FutureProvider.autoDispose
    .family<List<Tarefa>, int>((ref, solicitacaoId) async {
  final repository = ref.watch(tarefaRepositoryProvider);
  return repository.getBySolicitacao(solicitacaoId);
});

/// Alias para compatibilidade (deprecated - usar atividadesBySolicitacaoProvider)
final tarefasByCategoriaProvider = atividadesBySolicitacaoProvider;

/// Provider for atividades by gabinete (todas as atividades do gabinete)
final atividadesByGabineteProvider = FutureProvider.autoDispose<List<Tarefa>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repository = ref.watch(tarefaRepositoryProvider);
  return repository.getByGabinete(gabinete.id);
});

/// State notifier for atividade operations
class TarefaNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TarefaNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Tarefa?> create({
    required int solicitacaoId,
    required String titulo,
    String? descricao,
  }) async {
    state = const AsyncValue.loading();

    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      if (gabinete == null) {
        state = AsyncValue.error('Gabinete não encontrado', StackTrace.current);
        return null;
      }

      final repository = _ref.read(tarefaRepositoryProvider);
      final tarefa = await repository.create(
        gabineteId: gabinete.id,
        solicitacaoId: solicitacaoId,
        titulo: titulo,
        descricao: descricao,
      );

      // Invalidate provider to refresh
      _ref.invalidate(atividadesBySolicitacaoProvider(solicitacaoId));

      state = const AsyncValue.data(null);
      return tarefa;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateStatus(int id, int solicitacaoId, String status) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(tarefaRepositoryProvider);
      await repository.updateStatus(id, status);

      // Invalidate provider to refresh
      _ref.invalidate(atividadesBySolicitacaoProvider(solicitacaoId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(int id, int solicitacaoId) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(tarefaRepositoryProvider);
      await repository.delete(id);

      // Invalidate provider to refresh
      _ref.invalidate(atividadesBySolicitacaoProvider(solicitacaoId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for TarefaNotifier
final tarefaNotifierProvider =
    StateNotifierProvider<TarefaNotifier, AsyncValue<void>>((ref) {
  return TarefaNotifier(ref);
});

// ============================================
// NOTAS (vinculadas a solicitação)
// ============================================

/// Provider for notas by solicitacao
final notasBySolicitacaoProvider = FutureProvider.autoDispose
    .family<List<Nota>, int>((ref, solicitacaoId) async {
  final datasource = ref.watch(supabaseDatasourceProvider);
  
  final data = await datasource.select(
    table: 'notas',
    columns: '*',
    eq: {'solicitacao': solicitacaoId},
    orderBy: 'created_at',
    ascending: false,
  );
  
  return data.map((json) => Nota.fromJson(json)).toList();
});

/// Alias for backward compatibility - uses solicitacao notas
final notasByTarefaProvider = notasBySolicitacaoProvider;

/// State notifier for nota operations
class NotaNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotaNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Nota?> create({
    required int solicitacaoId,
    String? descricao,
    String? nomeAutor,
    String? autor,
  }) async {
    state = const AsyncValue.loading();

    try {
      final datasource = _ref.read(supabaseDatasourceProvider);
      
      final result = await datasource.insert(
        table: 'notas',
        data: {
          'solicitacao': solicitacaoId,
          if (descricao != null) 'descricao': descricao,
          if (nomeAutor != null) 'nome_autor': nomeAutor,
          if (autor != null) 'autor': autor,
        },
      );

      // Invalidate providers to refresh
      _ref.invalidate(notasBySolicitacaoProvider(solicitacaoId));

      state = const AsyncValue.data(null);
      return Nota.fromJson(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> delete(int id, int solicitacaoId) async {
    state = const AsyncValue.loading();

    try {
      final datasource = _ref.read(supabaseDatasourceProvider);
      
      await datasource.delete(
        table: 'notas',
        eq: {'id': id},
      );

      // Invalidate providers to refresh
      _ref.invalidate(notasBySolicitacaoProvider(solicitacaoId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for NotaNotifier
final notaNotifierProvider =
    StateNotifierProvider<NotaNotifier, AsyncValue<void>>((ref) {
  return NotaNotifier(ref);
});
