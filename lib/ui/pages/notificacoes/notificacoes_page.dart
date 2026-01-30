import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/models/notificacao.dart';
import '../../../providers/notificacao_providers.dart';
import '../../layouts/main_layout.dart';

/// Página de notificações
class NotificacoesPage extends ConsumerStatefulWidget {
  const NotificacoesPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends ConsumerState<NotificacoesPage> {
  TipoNotificacao? _filtroTipo;
  bool _mostrarSomenteNaoLidas = false;

  @override
  void initState() {
    super.initState();
    // Inicializar timeago em português
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
  }

  List<Notificacao> _filtrarNotificacoes(List<Notificacao> notificacoes) {
    var filtradas = notificacoes;

    if (_mostrarSomenteNaoLidas) {
      filtradas = filtradas.where((n) => !n.lida).toList();
    }

    if (_filtroTipo != null) {
      filtradas = filtradas.where((n) => n.tipo == _filtroTipo).toList();
    }

    return filtradas;
  }

  Color _getColorByPriority(PrioridadeNotificacao prioridade) {
    switch (prioridade) {
      case PrioridadeNotificacao.urgente:
        return Colors.red;
      case PrioridadeNotificacao.alta:
        return Colors.orange;
      case PrioridadeNotificacao.media:
        return Colors.blue;
      case PrioridadeNotificacao.baixa:
        return Colors.grey;
    }
  }

  IconData _getIconByType(TipoNotificacao tipo) {
    switch (tipo) {
      case TipoNotificacao.solicitacaoVencendo:
      case TipoNotificacao.solicitacaoVencida:
        return LucideIcons.alertCircle;
      case TipoNotificacao.cidadaoNaoAtendido:
        return LucideIcons.userX;
      case TipoNotificacao.novoCidadao:
        return LucideIcons.userPlus;
      case TipoNotificacao.novaSolicitacao:
        return LucideIcons.clipboardList;
      case TipoNotificacao.atividadePendente:
        return LucideIcons.checkSquare;
      case TipoNotificacao.mensagemNaoLida:
        return LucideIcons.messageSquare;
      case TipoNotificacao.sistema:
        return LucideIcons.info;
    }
  }

  String _getTipoLabel(TipoNotificacao tipo) {
    switch (tipo) {
      case TipoNotificacao.solicitacaoVencendo:
        return 'Solicitação Vencendo';
      case TipoNotificacao.solicitacaoVencida:
        return 'Solicitação Vencida';
      case TipoNotificacao.cidadaoNaoAtendido:
        return 'Cidadão Não Atendido';
      case TipoNotificacao.novoCidadao:
        return 'Novo Cidadão';
      case TipoNotificacao.novaSolicitacao:
        return 'Nova Solicitação';
      case TipoNotificacao.atividadePendente:
        return 'Atividade Pendente';
      case TipoNotificacao.mensagemNaoLida:
        return 'Mensagem Não Lida';
      case TipoNotificacao.sistema:
        return 'Sistema';
    }
  }

  void _handleNotificacaoTap(Notificacao notificacao) {
    // Marcar como lida
    ref.read(notificacaoNotifierProvider.notifier).marcarComoLida(
          notificacao.id,
        );

    // Navegar para a rota se existir
    if (notificacao.rota != null) {
      context.go(notificacao.rota!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificacoesAsync = ref.watch(notificacoesProvider);
    final countNaoLidas = ref.watch(notificacoesNaoLidasCountProvider);

    return MainLayout(
      title: 'Notificações',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header com ações
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    countNaoLidas.when(
                      data: (count) => Text(
                        count > 0
                            ? '$count ${count == 1 ? 'notificação não lida' : 'notificações não lidas'}'
                            : 'Todas as notificações foram lidas',
                        style: TextStyle(
                          color: count > 0 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Filtro por não lidas
                    FilterChip(
                      label: const Text('Não lidas'),
                      selected: _mostrarSomenteNaoLidas,
                      onSelected: (value) {
                        setState(() {
                          _mostrarSomenteNaoLidas = value;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    // Marcar todas como lidas
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(notificacaoNotifierProvider.notifier)
                            .marcarTodasComoLidas();
                      },
                      icon: const Icon(LucideIcons.checkCheck, size: 16),
                      label: const Text('Marcar todas como lidas'),
                    ),
                    const SizedBox(width: 8),
                    // Limpar lidas
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(notificacaoNotifierProvider.notifier)
                            .limparLidas();
                      },
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text('Limpar lidas'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filtros por tipo
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todas'),
                    selected: _filtroTipo == null,
                    onSelected: (value) {
                      setState(() {
                        _filtroTipo = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ...TipoNotificacao.values.map((tipo) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_getTipoLabel(tipo)),
                        avatar: Icon(
                          _getIconByType(tipo),
                          size: 16,
                        ),
                        selected: _filtroTipo == tipo,
                        onSelected: (value) {
                          setState(() {
                            _filtroTipo = value ? tipo : null;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lista de notificações
            Expanded(
              child: notificacoesAsync.when(
                data: (notificacoes) {
                  final filtradas = _filtrarNotificacoes(notificacoes);

                  if (filtradas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.bell,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _mostrarSomenteNaoLidas || _filtroTipo != null
                                ? 'Nenhuma notificação encontrada'
                                : 'Você não tem notificações',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                          ),
                          if (_mostrarSomenteNaoLidas || _filtroTipo != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _mostrarSomenteNaoLidas = false;
                                    _filtroTipo = null;
                                  });
                                },
                                child: const Text('Limpar filtros'),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtradas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notificacao = filtradas[index];
                      return _NotificacaoCard(
                        notificacao: notificacao,
                        onTap: () => _handleNotificacaoTap(notificacao),
                        onDelete: () {
                          ref
                              .read(notificacaoNotifierProvider.notifier)
                              .deletarNotificacao(notificacao.id);
                        },
                        getColorByPriority: _getColorByPriority,
                        getIconByType: _getIconByType,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar notificações',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de notificação
class _NotificacaoCard extends StatelessWidget {
  final Notificacao notificacao;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color Function(PrioridadeNotificacao) getColorByPriority;
  final IconData Function(TipoNotificacao) getIconByType;

  const _NotificacaoCard({
    Key? key,
    required this.notificacao,
    required this.onTap,
    required this.onDelete,
    required this.getColorByPriority,
    required this.getIconByType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cor = getColorByPriority(notificacao.prioridade);
    final icone = getIconByType(notificacao.tipo);

    return Container(
      decoration: BoxDecoration(
        color: notificacao.lida ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notificacao.lida ? Colors.grey.shade200 : cor.withValues(alpha: 0.3),
          width: notificacao.lida ? 1 : 2,
        ),
        boxShadow: notificacao.lida
            ? null
            : [
                BoxShadow(
                  color: cor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de prioridade
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // Ícone
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icone,
                  color: cor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notificacao.titulo,
                            style: TextStyle(
                              fontWeight: notificacao.lida
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          timeago.format(
                            notificacao.createdAt,
                            locale: 'pt_BR',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notificacao.mensagem,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!notificacao.lida) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Não lida',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Botão deletar
              IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                onPressed: onDelete,
                tooltip: 'Excluir notificação',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
