import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/mensagem.dart';
import '../data/models/atendimento.dart';
import 'core_providers.dart';

// ============================================
// ATENDIMENTO PROVIDERS
// ============================================

/// Provider for all atendimentos (conversations)
final atendimentosProvider = FutureProvider.autoDispose
    .family<List<Atendimento>, AtendimentosParams>((ref, params) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repository = ref.watch(atendimentoRepositoryProvider);
  final usuario = await ref.watch(currentUserProvider.future);

  final lista = await repository.getByGabinete(
    gabinete.id,
    status: params.status,
    limit: params.limit,
    searchTerm: params.searchTerm,
  );

  final tipo = usuario?.tipo?.toLowerCase();
  final isVereador = tipo == 'vereador' || tipo == 'admin';
  if (!isVereador) {
    return lista.where((a) => a.autorizado).toList();
  }
  return lista;
});

/// Provider for active atendimentos only
final activeAtendimentosProvider = FutureProvider.autoDispose<List<Atendimento>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repository = ref.watch(atendimentoRepositoryProvider);
  return repository.getActive(gabinete.id);
});

/// Provider for a single atendimento
final atendimentoProvider = FutureProvider.autoDispose
    .family<Atendimento?, int>((ref, id) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  final repository = ref.watch(atendimentoRepositoryProvider);
  return repository.getById(id, gabineteId: gabinete?.id);
});

/// Currently selected atendimento
final selectedAtendimentoProvider = StateProvider<Atendimento?>((ref) => null);

// ============================================
// MENSAGEM PROVIDERS
// ============================================

/// Provider for messages in an atendimento
final mensagensProvider = FutureProvider.autoDispose
    .family<List<Mensagem>, int>((ref, atendimentoId) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  final repository = ref.watch(mensagemRepositoryProvider);
  return repository.getByAtendimento(
    atendimentoId,
    gabineteId: gabinete?.id,
    telefoneGabinete: gabinete?.telefone,
  );
});

/// Stream provider for realtime messages
final mensagensStreamProvider = StreamProvider.autoDispose
    .family<List<Mensagem>, int>((ref, atendimentoId) {
  final repository = ref.watch(mensagemRepositoryProvider);
  final gabineteAsync = ref.watch(currentGabineteProvider);

  return gabineteAsync.when(
    data: (gabinete) => repository.watchMessages(
      atendimentoId,
      gabineteId: gabinete?.id,
      telefoneGabinete: gabinete?.telefone,
    ),
    loading: () => const Stream.empty(),
    error: (_, __) => repository.watchMessages(atendimentoId),
  );
});

/// Provider para mensagens pendentes (optimistic update)
/// Armazena mensagens que estão sendo enviadas antes de chegarem no banco
final pendingMessagesProvider =
    StateNotifierProvider<PendingMessagesNotifier, Map<int, List<Mensagem>>>(
  (ref) => PendingMessagesNotifier(),
);

/// Notifier para gerenciar mensagens pendentes
class PendingMessagesNotifier extends StateNotifier<Map<int, List<Mensagem>>> {
  PendingMessagesNotifier() : super({});

  /// Adiciona uma mensagem pendente para um atendimento
  void addPending(int atendimentoId, Mensagem msg) {
    final current = state[atendimentoId] ?? [];
    state = {
      ...state,
      atendimentoId: [...current, msg],
    };
  }

  /// Marca uma mensagem pendente como enviada (ou remove se já está no banco)
  void markSent(int atendimentoId, String tempId) {
    final current = state[atendimentoId];
    if (current == null) return;

    state = {
      ...state,
      atendimentoId: current
          .map((m) => m.tempId == tempId ? m.copyWith(status: MensagemStatus.sent) : m)
          .toList(),
    };
  }

  /// Marca uma mensagem pendente como erro
  void markError(int atendimentoId, String tempId) {
    final current = state[atendimentoId];
    if (current == null) return;

    state = {
      ...state,
      atendimentoId: current
          .map((m) => m.tempId == tempId ? m.copyWith(status: MensagemStatus.error) : m)
          .toList(),
    };
  }

  /// Remove uma mensagem pendente (quando chega do banco)
  void removePending(int atendimentoId, String tempId) {
    final current = state[atendimentoId];
    if (current == null) return;

    state = {
      ...state,
      atendimentoId: current.where((m) => m.tempId != tempId).toList(),
    };
  }

  /// Remove mensagens pendentes antigas (enviadas há mais de 5 segundos)
  void cleanupOldSent(int atendimentoId) {
    final current = state[atendimentoId];
    if (current == null) return;

    final threshold = DateTime.now().subtract(const Duration(seconds: 5));
    state = {
      ...state,
      atendimentoId: current.where((m) {
        // Mantém se está enviando ou se foi enviada recentemente
        if (m.status == MensagemStatus.sending) return true;
        if (m.status == MensagemStatus.error) return true;
        return m.createdAt.isAfter(threshold);
      }).toList(),
    };
  }

  /// Obtém mensagens pendentes de um atendimento
  List<Mensagem> getPending(int atendimentoId) {
    return state[atendimentoId] ?? [];
  }
}

/// Provider que combina mensagens do banco + pendentes
final combinedMessagesProvider = Provider.autoDispose
    .family<AsyncValue<List<Mensagem>>, int>((ref, atendimentoId) {
  final dbMessages = ref.watch(mensagensStreamProvider(atendimentoId));
  final pendingMessages = ref.watch(pendingMessagesProvider)[atendimentoId] ?? [];

  return dbMessages.whenData((messages) {
    // Limpa mensagens pendentes que já chegaram no banco
    final pendingNotifier = ref.read(pendingMessagesProvider.notifier);
    for (final pending in pendingMessages) {
      if (pending.tempId != null) {
        // Verifica se uma mensagem similar já existe no banco
        // (mesmo texto, mesma hora aproximada, mesmo atendimento)
        final exists = messages.any((m) =>
            m.mensagem == pending.mensagem &&
            m.atendimentoId == pending.atendimentoId &&
            m.createdAt.difference(pending.createdAt).inSeconds.abs() < 10);
        if (exists) {
          pendingNotifier.removePending(atendimentoId, pending.tempId!);
        }
      }
    }

    // Filtra pendentes que ainda não estão no banco
    final stillPending = pendingMessages.where((p) {
      final exists = messages.any((m) =>
          m.mensagem == p.mensagem &&
          m.atendimentoId == p.atendimentoId &&
          m.createdAt.difference(p.createdAt).inSeconds.abs() < 10);
      return !exists;
    }).toList();

    // Combina: mensagens do banco + pendentes no final
    return [...messages, ...stillPending];
  });
});

// ============================================
// NOTIFIERS
// ============================================

/// Notifier for atendimento operations
class AtendimentoNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AtendimentoNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> encerrar(int atendimentoId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(atendimentoRepositoryProvider);
      await repository.encerrar(atendimentoId);
      
      // Clear selection if this was selected
      final selected = _ref.read(selectedAtendimentoProvider);
      if (selected?.id == atendimentoId) {
        _ref.read(selectedAtendimentoProvider.notifier).state = null;
      }
      
      // Refresh list
      _ref.invalidate(atendimentosProvider);
      _ref.invalidate(activeAtendimentosProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reabrir(int atendimentoId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(atendimentoRepositoryProvider);
      await repository.updateStatus(atendimentoId, 'em atendimento');
      
      // Refresh list and current selection
      _ref.invalidate(atendimentosProvider);
      _ref.invalidate(activeAtendimentosProvider);
      _ref.invalidate(atendimentoProvider(atendimentoId));
      
      // Update selected atendimento with new status
      final selected = _ref.read(selectedAtendimentoProvider);
      if (selected?.id == atendimentoId) {
        final updated = await repository.getById(atendimentoId);
        if (updated != null) {
          _ref.read(selectedAtendimentoProvider.notifier).state = updated;
        }
      }
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> linkCidadao(int atendimentoId, int cidadaoId) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(atendimentoRepositoryProvider);
      await repository.linkCidadao(atendimentoId, cidadaoId);
      
      // Refresh
      _ref.invalidate(atendimentoProvider(atendimentoId));
      _ref.invalidate(atendimentosProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Atualizar status do atendimento (igual ao encerrar)
  Future<void> updateStatus(int atendimentoId, String status) async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(atendimentoRepositoryProvider);
      await repository.updateStatus(atendimentoId, status);
      
      // Update selected atendimento with new status
      final selected = _ref.read(selectedAtendimentoProvider);
      if (selected?.id == atendimentoId) {
        _ref.read(selectedAtendimentoProvider.notifier).state = 
            selected!.copyWith(status: status);
      }
      
      // Refresh lists
      _ref.invalidate(atendimentosProvider);
      _ref.invalidate(activeAtendimentosProvider);
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Alterna o campo autorizado (lock) do atendimento
  Future<void> atualizarAutorizado(int atendimentoId, bool autorizado) async {
    state = const AsyncValue.loading();
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      final repository = _ref.read(atendimentoRepositoryProvider);
      await repository.updateAutorizado(
        atendimentoId,
        autorizado,
        gabineteId: gabinete?.id,
      );

      // Atualiza seleção em memória
      final selected = _ref.read(selectedAtendimentoProvider);
      if (selected?.id == atendimentoId) {
        _ref.read(selectedAtendimentoProvider.notifier).state =
            selected!.copyWith(autorizado: autorizado);
      }

      // Refresh listas
      _ref.invalidate(atendimentosProvider);
      _ref.invalidate(activeAtendimentosProvider);
      _ref.invalidate(atendimentoProvider(atendimentoId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  Future<void> salvarObsGerais(int atendimentoId, String? obs) async {
    state = const AsyncValue.loading();
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      final repository = _ref.read(atendimentoRepositoryProvider);

      developer.log(
        'salvarObsGerais -> atendimentoId=$atendimentoId, gabineteId=${gabinete?.id}, obs="${obs ?? ""}"',
        name: 'AtendimentoNotifier',
      );

      await repository.updateObsGerais(
        atendimentoId,
        obs,
        gabineteId: gabinete?.id,
      );

      // Atualiza selecionado em memÃ³ria
      final selected = _ref.read(selectedAtendimentoProvider);
      if (selected?.id == atendimentoId) {
        _ref.read(selectedAtendimentoProvider.notifier).state =
            selected!.copyWith(obsGerais: obs);
      }

      // Refresh providers
      _ref.invalidate(atendimentoProvider(atendimentoId));
      _ref.invalidate(atendimentosProvider);
      _ref.invalidate(activeAtendimentosProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      developer.log(
        'salvarObsGerais error: $e',
        name: 'AtendimentoNotifier',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
    }
  }
}

final atendimentoNotifierProvider =
    StateNotifierProvider<AtendimentoNotifier, AsyncValue<void>>((ref) {
  return AtendimentoNotifier(ref);
});

/// Notifier for message operations
class MensagemNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MensagemNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Marca mensagens de um atendimento como lidas no WhatsApp/UazAPI
  Future<void> marcarComoLidas(int atendimentoId) async {
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      if (gabinete?.tokenZapi == null || (gabinete!.tokenZapi?.isEmpty ?? true)) {
        return; // sem token da instância, nada a fazer
      }

      final repository = _ref.read(mensagemRepositoryProvider);
      final mensagens = await repository.getByAtendimento(
        atendimentoId,
        gabineteId: gabinete.id,
        limit: 200,
      );

      // Pega IDs originais do WhatsApp apenas das mensagens recebidas
      final ids = mensagens
          .where((m) => !m.isFromMe && (m.idMensagem?.isNotEmpty ?? false))
          .map((m) => m.idMensagem!)
          .toSet()
          .toList();

      if (ids.isEmpty) return;

      final uazapi = _ref.read(uazapiServiceProvider);
      await uazapi.marcarMensagensComoLidas(
        instanceToken: gabinete.tokenZapi!,
        messageIds: ids,
      );
    } catch (_) {
      // silencia para não quebrar a UI
    }
  }

  Future<Mensagem?> send({
    required int atendimentoId,
    required String telefone,
    required String mensagem,
    String tipo = 'text',
    int? cidadaoId,
    String? mediaUrl,
  }) async {
    // Não usar loading para não bloquear a UI
    final gabinete = await _ref.read(currentGabineteProvider.future);
    if (gabinete == null) {
      state = AsyncValue.error('Gabinete não encontrado', StackTrace.current);
      return null;
    }

    // 1. Criar mensagem pendente (optimistic) IMEDIATAMENTE
    final pendingMsg = Mensagem.pending(
      gabineteId: gabinete.id,
      atendimentoId: atendimentoId,
      telefone: gabinete.telefone ?? telefone,
      mensagem: mensagem,
      tipo: tipo,
      cidadaoId: cidadaoId,
      mediaUrl: mediaUrl,
    );

    // Adiciona à lista de pendentes para exibir na UI
    _ref.read(pendingMessagesProvider.notifier).addPending(atendimentoId, pendingMsg);

    try {
      // 2. Enviar via UazAPI
      final uazapiService = _ref.read(uazapiServiceProvider);
      final instanceToken = gabinete.token;

      if (instanceToken == null || instanceToken.isEmpty) {
        // Marca como erro
        _ref.read(pendingMessagesProvider.notifier).markError(atendimentoId, pendingMsg.tempId!);
        state = AsyncValue.error('Token da instância não configurado', StackTrace.current);
        return null;
      }

      final apiResponse = await uazapiService.enviarMensagem(
        instanceToken: instanceToken,
        telefone: telefone,
        mensagem: mensagem,
      );

      if (!apiResponse.isSuccess) {
        // Marca como erro
        _ref.read(pendingMessagesProvider.notifier).markError(atendimentoId, pendingMsg.tempId!);
        state = AsyncValue.error(apiResponse.error ?? 'Erro ao enviar mensagem', StackTrace.current);
        return null;
      }

      // 3. Marca como enviado (API respondeu OK)
      _ref.read(pendingMessagesProvider.notifier).markSent(atendimentoId, pendingMsg.tempId!);

      // Não salvar no banco aqui - o n8n já faz o insert via webhook

      // Refresh messages após um tempo para o n8n processar
      // A mensagem pendente será removida automaticamente quando chegar do banco
      Future.delayed(const Duration(seconds: 3), () {
        _ref.read(pendingMessagesProvider.notifier).cleanupOldSent(atendimentoId);
        _ref.invalidate(atendimentosProvider(AtendimentosParams(status: 'em atendimento')));
        _ref.invalidate(atendimentosProvider(AtendimentosParams(status: 'finalizado')));
        _ref.invalidate(activeAtendimentosProvider);
      });

      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final mensagemNotifierProvider =
    StateNotifierProvider<MensagemNotifier, AsyncValue<void>>((ref) {
  return MensagemNotifier(ref);
});

// ============================================
// PARAMS CLASSES
// ============================================

class AtendimentosParams {
  final String? status;
  final int? limit;
  final String? searchTerm;

  const AtendimentosParams({
    this.status,
    this.limit,
    this.searchTerm,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AtendimentosParams &&
        other.status == status &&
        other.limit == limit &&
        other.searchTerm == searchTerm;
  }

  @override
  int get hashCode => Object.hash(status, limit, searchTerm);
}
