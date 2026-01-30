import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/notificacao.dart';
import '../../providers/notificacao_providers.dart';

/// Toast de notificação estilo WhatsApp
class NotificationToast extends ConsumerStatefulWidget {
  final Notificacao notificacao;
  final VoidCallback onDismiss;

  const NotificationToast({
    Key? key,
    required this.notificacao,
    required this.onDismiss,
  }) : super(key: key);

  @override
  ConsumerState<NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends ConsumerState<NotificationToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss após 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _getColorByPriority() {
    switch (widget.notificacao.prioridade) {
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

  IconData _getIconByType() {
    switch (widget.notificacao.tipo) {
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

  void _handleTap() {
    // Marcar como lida
    ref.read(notificacaoNotifierProvider.notifier).marcarComoLida(
          widget.notificacao.id,
        );

    // Navegar para a rota se existir
    if (widget.notificacao.rota != null) {
      context.go(widget.notificacao.rota!);
    }

    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 16),
            width: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getColorByPriority().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getIconByType(),
                        color: _getColorByPriority(),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Conteúdo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.notificacao.titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeago.format(
                                  widget.notificacao.createdAt,
                                  locale: 'pt_BR',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notificacao.mensagem,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botão fechar
                    IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: _dismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget que gerencia a fila de toasts
class NotificationToastContainer extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationToastContainer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  ConsumerState<NotificationToastContainer> createState() =>
      _NotificationToastContainerState();
}

class _NotificationToastContainerState
    extends ConsumerState<NotificationToastContainer> {
  final List<Notificacao> _toasts = [];

  @override
  Widget build(BuildContext context) {
    // Observar novas notificações
    ref.listen<Notificacao?>(showNotificationToastProvider, (previous, next) {
      if (next != null && !_toasts.any((t) => t.id == next.id)) {
        setState(() {
          _toasts.add(next);
        });
        // Limpar o provider
        Future.microtask(() {
          ref.read(showNotificationToastProvider.notifier).state = null;
        });
      }
    });

    return Stack(
      children: [
        widget.child,
        // Toasts no canto superior direito
        Positioned(
          top: 0,
          right: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _toasts.map((notificacao) {
              return NotificationToast(
                key: ValueKey(notificacao.id),
                notificacao: notificacao,
                onDismiss: () {
                  setState(() {
                    _toasts.remove(notificacao);
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
