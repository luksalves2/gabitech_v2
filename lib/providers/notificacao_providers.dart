import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notificacao.dart';
import '../data/repositories/notificacao_repository.dart';
import 'core_providers.dart';

/// Provider for NotificacaoRepository
final notificacaoRepositoryProvider = Provider<NotificacaoRepository>((ref) {
  final datasource = ref.watch(supabaseDatasourceProvider);
  return NotificacaoRepository(datasource);
});

/// Provider for notifications list
final notificacoesProvider = FutureProvider<List<Notificacao>>((ref) async {
  final repository = ref.watch(notificacaoRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  final currentGabinete = await ref.watch(currentGabineteProvider.future);

  if (currentUser == null) return [];

  return repository.getNotificacoes(
    usuarioId: currentUser.uuid,
    gabineteId: currentGabinete?.id,
  );
});

/// Provider for unread notifications count
final notificacoesNaoLidasCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(notificacaoRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  final currentGabinete = await ref.watch(currentGabineteProvider.future);

  if (currentUser == null) return 0;

  return repository.getNotificacoesNaoLidasCount(
    usuarioId: currentUser.uuid,
    gabineteId: currentGabinete?.id,
  );
});

/// Provider for unread notifications only
final notificacoesNaoLidasProvider =
    FutureProvider<List<Notificacao>>((ref) async {
  final repository = ref.watch(notificacaoRepositoryProvider);
  final currentUser = await ref.watch(currentUserProvider.future);
  final currentGabinete = await ref.watch(currentGabineteProvider.future);

  if (currentUser == null) return [];

  return repository.getNotificacoes(
    usuarioId: currentUser.uuid,
    gabineteId: currentGabinete?.id,
    somenteNaoLidas: true,
  );
});

/// Notifier for managing notification operations
class NotificacaoNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificacaoNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> marcarComoLida(int notificacaoId) async {
    try {
      final repository = _ref.read(notificacaoRepositoryProvider);
      await repository.marcarComoLida(notificacaoId);

      // Refresh notifications
      _ref.invalidate(notificacoesProvider);
      _ref.invalidate(notificacoesNaoLidasCountProvider);
      _ref.invalidate(notificacoesNaoLidasProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> marcarTodasComoLidas() async {
    try {
      final repository = _ref.read(notificacaoRepositoryProvider);
      final currentUser = await _ref.read(currentUserProvider.future);
      final currentGabinete = await _ref.read(currentGabineteProvider.future);

      if (currentUser == null) return;

      await repository.marcarTodasComoLidas(
        usuarioId: currentUser.uuid,
        gabineteId: currentGabinete?.id,
      );

      // Refresh notifications
      _ref.invalidate(notificacoesProvider);
      _ref.invalidate(notificacoesNaoLidasCountProvider);
      _ref.invalidate(notificacoesNaoLidasProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deletarNotificacao(int notificacaoId) async {
    try {
      final repository = _ref.read(notificacaoRepositoryProvider);
      await repository.deletarNotificacao(notificacaoId);

      // Refresh notifications
      _ref.invalidate(notificacoesProvider);
      _ref.invalidate(notificacoesNaoLidasCountProvider);
      _ref.invalidate(notificacoesNaoLidasProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> limparLidas() async {
    try {
      final repository = _ref.read(notificacaoRepositoryProvider);
      final currentUser = await _ref.read(currentUserProvider.future);
      final currentGabinete = await _ref.read(currentGabineteProvider.future);

      if (currentUser == null) return;

      await repository.limparLidas(
        usuarioId: currentUser.uuid,
        gabineteId: currentGabinete?.id,
      );

      // Refresh notifications
      _ref.invalidate(notificacoesProvider);
      _ref.invalidate(notificacoesNaoLidasCountProvider);
      _ref.invalidate(notificacoesNaoLidasProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create notification (for testing or manual creation)
  Future<void> criarNotificacao({
    required TipoNotificacao tipo,
    required PrioridadeNotificacao prioridade,
    required String titulo,
    required String mensagem,
    String? rota,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final repository = _ref.read(notificacaoRepositoryProvider);
      final currentUser = await _ref.read(currentUserProvider.future);
      final currentGabinete = await _ref.read(currentGabineteProvider.future);

      if (currentUser == null) return;

      await repository.criarNotificacao(
        usuarioId: currentUser.uuid,
        gabineteId: currentGabinete?.id,
        tipo: tipo,
        prioridade: prioridade,
        titulo: titulo,
        mensagem: mensagem,
        rota: rota,
        metadata: metadata,
      );
      // Dispara toast para UI
      final latest = await repository.getNotificacoes(
        usuarioId: currentUser.uuid,
        gabineteId: currentGabinete?.id,
        somenteNaoLidas: true,
      );
      if (latest.isNotEmpty) {
        _ref.read(showNotificationToastProvider.notifier).state = latest.first;
      }

      // Refresh notifications
      _ref.invalidate(notificacoesProvider);
      _ref.invalidate(notificacoesNaoLidasCountProvider);
      _ref.invalidate(notificacoesNaoLidasProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificacaoNotifierProvider =
    StateNotifierProvider<NotificacaoNotifier, AsyncValue<void>>((ref) {
  return NotificacaoNotifier(ref);
});

/// Provider for showing toast notifications
final showNotificationToastProvider =
    StateProvider<Notificacao?>((ref) => null);
