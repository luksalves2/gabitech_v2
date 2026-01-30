import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notificacao.dart';
import '../data/repositories/notificacao_repository.dart';
import '../providers/notificacao_providers.dart';

/// Serviço para gerenciar notificações inteligentes do sistema
class NotificationService {
  final NotificacaoRepository _repository;
  final Ref _ref;

  NotificationService(this._repository, this._ref);

  /// Verifica solicitações vencendo (próximas 24h) e gera notificações
  Future<void> verificarSolicitacoesVencendo() async {
    try {
      // TODO: Implementar consulta ao banco para buscar solicitações vencendo
      // SELECT * FROM solicitacoes WHERE prazo_fim BETWEEN NOW() AND NOW() + INTERVAL '24 hours' AND status != 'concluida'

      // Para cada solicitação vencendo, criar notificação
      // await _repository.criarNotificacao(
      //   usuarioId: responsavelId,
      //   gabineteId: gabineteId,
      //   tipo: TipoNotificacao.solicitacaoVencendo,
      //   prioridade: PrioridadeNotificacao.alta,
      //   titulo: 'Solicitação vencendo em breve',
      //   mensagem: 'A solicitação #${solicitacaoId} vence em menos de 24 horas',
      //   rota: '/solicitacoes',
      //   metadata: {'solicitacaoId': solicitacaoId},
      // );
    } catch (e) {
      // Log error
      print('Erro ao verificar solicitações vencendo: $e');
    }
  }

  /// Verifica solicitações vencidas e gera notificações
  Future<void> verificarSolicitacoesVencidas() async {
    try {
      // TODO: Implementar consulta ao banco para buscar solicitações vencidas
      // SELECT * FROM solicitacoes WHERE prazo_fim < NOW() AND status != 'concluida'

      // Para cada solicitação vencida, criar notificação
      // await _repository.criarNotificacao(
      //   usuarioId: responsavelId,
      //   gabineteId: gabineteId,
      //   tipo: TipoNotificacao.solicitacaoVencida,
      //   prioridade: PrioridadeNotificacao.urgente,
      //   titulo: 'Solicitação vencida!',
      //   mensagem: 'A solicitação #${solicitacaoId} está vencida há ${diasVencida} dias',
      //   rota: '/solicitacoes',
      //   metadata: {'solicitacaoId': solicitacaoId},
      // );
    } catch (e) {
      print('Erro ao verificar solicitações vencidas: $e');
    }
  }

  /// Verifica cidadãos não atendidos do dia anterior
  Future<void> verificarCidadaosNaoAtendidos() async {
    try {
      // TODO: Implementar consulta ao banco
      // SELECT COUNT(*) FROM cidadaos WHERE created_at >= CURRENT_DATE - INTERVAL '1 day' AND created_at < CURRENT_DATE AND status = 'aguardando'

      // Se houver cidadãos não atendidos, criar notificação
      // await _repository.criarNotificacao(
      //   gabineteId: gabineteId,
      //   tipo: TipoNotificacao.cidadaoNaoAtendido,
      //   prioridade: PrioridadeNotificacao.media,
      //   titulo: 'Cidadãos aguardando atendimento',
      //   mensagem: 'Você tem $count cidadãos que ficaram sem atendimento ontem',
      //   rota: '/cidadaos',
      // );
    } catch (e) {
      print('Erro ao verificar cidadãos não atendidos: $e');
    }
  }

  /// Verifica mensagens não lidas
  Future<void> verificarMensagensNaoLidas() async {
    try {
      // TODO: Implementar consulta ao banco
      // SELECT COUNT(*) FROM mensagens WHERE lida = false AND destinatario_id = userId

      // Se houver muitas mensagens não lidas, criar notificação
      // await _repository.criarNotificacao(
      //   usuarioId: userId,
      //   tipo: TipoNotificacao.mensagemNaoLida,
      //   prioridade: PrioridadeNotificacao.media,
      //   titulo: 'Mensagens não lidas',
      //   mensagem: 'Você tem $count mensagens não lidas',
      //   rota: '/mensagens',
      // );
    } catch (e) {
      print('Erro ao verificar mensagens não lidas: $e');
    }
  }

  /// Verifica atividades pendentes
  Future<void> verificarAtividadesPendentes() async {
    try {
      // TODO: Implementar consulta ao banco
      // SELECT COUNT(*) FROM atividades WHERE status = 'pendente' AND data_prevista < NOW()

      // Se houver atividades atrasadas, criar notificação
      // await _repository.criarNotificacao(
      //   gabineteId: gabineteId,
      //   tipo: TipoNotificacao.atividadePendente,
      //   prioridade: PrioridadeNotificacao.alta,
      //   titulo: 'Atividades atrasadas',
      //   mensagem: 'Você tem $count atividades com prazo vencido',
      //   rota: '/atividades',
      // );
    } catch (e) {
      print('Erro ao verificar atividades pendentes: $e');
    }
  }

  /// Criar notificação de novo cidadão cadastrado
  Future<void> notificarNovoCidadao({
    required int gabineteId,
    required String nomeCidadao,
    required int cidadaoId,
  }) async {
    try {
      final notif = await _repository.criarNotificacao(
        gabineteId: gabineteId,
        tipo: TipoNotificacao.novoCidadao,
        prioridade: PrioridadeNotificacao.baixa,
        titulo: 'Novo cidadão cadastrado',
        mensagem: '$nomeCidadao foi cadastrado no sistema',
        rota: '/cidadaos',
        metadata: {'cidadaoId': cidadaoId},
      );

      _showToast(notif);
    } catch (e) {
      print('Erro ao notificar novo cidadão: $e');
    }
  }

  /// Criar notificação de nova solicitação
  Future<void> notificarNovaSolicitacao({
    required int gabineteId,
    required String? responsavelId,
    required String titulo,
    required int solicitacaoId,
  }) async {
    try {
      final notif = await _repository.criarNotificacao(
        usuarioId: responsavelId,
        gabineteId: gabineteId,
        tipo: TipoNotificacao.novaSolicitacao,
        prioridade: PrioridadeNotificacao.media,
        titulo: 'Nova solicitação criada',
        mensagem: titulo,
        rota: '/solicitacoes',
        metadata: {'solicitacaoId': solicitacaoId},
      );

      _showToast(notif);
    } catch (e) {
      print('Erro ao notificar nova solicitação: $e');
    }
  }

  /// Criar notificação de sistema
  Future<void> notificarSistema({
    int? gabineteId,
    String? usuarioId,
    required String titulo,
    required String mensagem,
    String? rota,
    PrioridadeNotificacao prioridade = PrioridadeNotificacao.media,
  }) async {
    try {
      final notif = await _repository.criarNotificacao(
        usuarioId: usuarioId,
        gabineteId: gabineteId,
        tipo: TipoNotificacao.sistema,
        prioridade: prioridade,
        titulo: titulo,
        mensagem: mensagem,
        rota: rota,
      );

      _showToast(notif);
    } catch (e) {
      print('Erro ao criar notificação de sistema: $e');
    }
  }

  /// Executar todas as verificações periódicas
  Future<void> executarVerificacoesPeriodicas() async {
    await Future.wait([
      verificarSolicitacoesVencendo(),
      verificarSolicitacoesVencidas(),
      verificarCidadaosNaoAtendidos(),
      verificarMensagensNaoLidas(),
      verificarAtividadesPendentes(),
    ]);

    // Refresh providers
    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(notificacoesNaoLidasCountProvider);
  }

  /// Mostrar toast para uma notificação recém-criada
  void _showToast(Notificacao notificacao) {
    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(notificacoesNaoLidasCountProvider);
    _ref.read(showNotificationToastProvider.notifier).state = notificacao;
  }

  /// Criar notificações de exemplo (para testes)
  Future<void> criarNotificacoesExemplo({
    required int gabineteId,
    String? usuarioId,
  }) async {
    final exemplos = [
      {
        'tipo': TipoNotificacao.solicitacaoVencendo,
        'prioridade': PrioridadeNotificacao.alta,
        'titulo': 'Solicitação vencendo amanhã',
        'mensagem': 'A solicitação #1234 - Troca de lâmpadas na Rua A vence amanhã às 18h',
        'rota': '/solicitacoes',
      },
      {
        'tipo': TipoNotificacao.solicitacaoVencida,
        'prioridade': PrioridadeNotificacao.urgente,
        'titulo': '4 solicitações com prazo vencido',
        'mensagem': 'Você tem 4 solicitações que já passaram do prazo e precisam de atenção',
        'rota': '/solicitacoes',
      },
      {
        'tipo': TipoNotificacao.cidadaoNaoAtendido,
        'prioridade': PrioridadeNotificacao.media,
        'titulo': '5 cidadãos não atendidos',
        'mensagem': 'Há 5 cidadãos que ficaram aguardando atendimento desde ontem',
        'rota': '/cidadaos',
      },
      {
        'tipo': TipoNotificacao.novoCidadao,
        'prioridade': PrioridadeNotificacao.baixa,
        'titulo': 'Novo cidadão cadastrado',
        'mensagem': 'Maria Silva foi cadastrada no sistema há 5 minutos',
        'rota': '/cidadaos',
      },
      {
        'tipo': TipoNotificacao.novaSolicitacao,
        'prioridade': PrioridadeNotificacao.media,
        'titulo': 'Nova solicitação criada',
        'mensagem': 'João Santos criou uma solicitação: Conserto de calçada',
        'rota': '/solicitacoes',
      },
      {
        'tipo': TipoNotificacao.atividadePendente,
        'prioridade': PrioridadeNotificacao.alta,
        'titulo': '3 atividades atrasadas',
        'mensagem': 'Você tem 3 atividades que já passaram da data prevista',
        'rota': '/atividades',
      },
      {
        'tipo': TipoNotificacao.mensagemNaoLida,
        'prioridade': PrioridadeNotificacao.media,
        'titulo': '12 mensagens não lidas',
        'mensagem': 'Você tem 12 mensagens do WhatsApp aguardando resposta',
        'rota': '/mensagens',
      },
      {
        'tipo': TipoNotificacao.sistema,
        'prioridade': PrioridadeNotificacao.baixa,
        'titulo': 'Bem-vindo ao Gabitech!',
        'mensagem': 'Sistema de notificações inteligentes ativado com sucesso',
        'rota': null,
      },
    ];

    for (final exemplo in exemplos) {
      final notif = await _repository.criarNotificacao(
        usuarioId: usuarioId,
        gabineteId: gabineteId,
        tipo: exemplo['tipo'] as TipoNotificacao,
        prioridade: exemplo['prioridade'] as PrioridadeNotificacao,
        titulo: exemplo['titulo'] as String,
        mensagem: exemplo['mensagem'] as String,
        rota: exemplo['rota'] as String?,
      );
      _showToast(notif);

      // Delay entre notificações para não sobrecarregar
      
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Refresh
    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(notificacoesNaoLidasCountProvider);
  }
}

/// Provider do NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final repository = ref.watch(notificacaoRepositoryProvider);
  return NotificationService(repository, ref);
});
