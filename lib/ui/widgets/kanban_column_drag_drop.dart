import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/solicitacao.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Kanban column widget with drag and drop support
class KanbanColumnDragDrop extends StatelessWidget {
  final SolicitacaoStatus status;
  final List<Solicitacao> solicitacoes;
  final Function(Solicitacao)? onCardTap;
  final Function(Solicitacao, SolicitacaoStatus)? onStatusChange;
  final bool isLoading;

  const KanbanColumnDragDrop({
    super.key,
    required this.status,
    required this.solicitacoes,
    this.onCardTap,
    this.onStatusChange,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Solicitacao>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        final currentStatus = details.data.status?.toLowerCase() ?? 'todos';
        final targetStatus = status.value.toLowerCase();

        // Não pode arrastar para o mesmo status
        if (currentStatus == targetStatus) return false;

        // Coluna "Em Atraso" não aceita cards arrastados manualmente
        // (cards vão para lá automaticamente quando o prazo expira)
        if (targetStatus == 'em atraso') return false;

        // Cards em "Em Atraso" só podem ir para "Finalizados"
        if (currentStatus == 'em atraso' && targetStatus != 'finalizado') {
          return false;
        }

        return true;
      },
      onAcceptWithDetails: (details) {
        onStatusChange?.call(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isHovering ? status.color.withValues(alpha: 0.05) : null,
            borderRadius: BorderRadius.circular(12),
            border:
                isHovering ? Border.all(color: status.color, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          // Indicador de coluna automática para "Em Atraso"
                          if (status == SolicitacaoStatus.emAtraso)
                            Text(
                              'Automático por prazo',
                              style: TextStyle(
                                fontSize: 9,
                                color: status.color.withValues(alpha: 0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${solicitacoes.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.03),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: status.color.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : solicitacoes.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Nenhuma solicitação',
                                  style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : ScrollConfiguration(
                              behavior:
                                  ScrollConfiguration.of(context).copyWith(
                                dragDevices: {},
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: solicitacoes.length,
                                itemBuilder: (context, index) {
                                  final sol = solicitacoes[index];
                                  return _DraggableKanbanCard(
                                    solicitacao: sol,
                                    onTap: () => onCardTap?.call(sol),
                                  );
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableKanbanCard extends StatelessWidget {
  final Solicitacao solicitacao;
  final VoidCallback? onTap;

  const _DraggableKanbanCard({
    required this.solicitacao,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<Solicitacao>(
      data: solicitacao,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 260,
          child: _KanbanCardContent(solicitacao: solicitacao, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _KanbanCardContent(solicitacao: solicitacao),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: _KanbanCardContent(solicitacao: solicitacao),
          ),
        ),
      ),
    );
  }
}

class _KanbanCardContent extends StatelessWidget {
  final Solicitacao solicitacao;
  final bool isDragging;

  const _KanbanCardContent({
    required this.solicitacao,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category and Priority row
          Row(
            children: [
              if (solicitacao.categoria != null)
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      solicitacao.categoria!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (solicitacao.prioridade != null) ...[
                const SizedBox(width: 8),
                _PriorityBadge(prioridade: solicitacao.prioridade!),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            solicitacao.titulo ?? 'Sem título',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Cidadão info
          if (solicitacao.cidadao != null) ...[
            Row(
              children: [
                CachedAvatar(
                  radius: 12,
                  imageUrl: solicitacao.cidadao?.foto,
                  name: solicitacao.cidadao?.nome,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solicitacao.cidadao!.nome ?? 'Cidadão',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (solicitacao.cidadao!.perfil != null)
                        Text(
                          solicitacao.cidadao!.perfil!,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Footer: Prazo and Assessor
          Row(
            children: [
              if (solicitacao.prazo != null) ...[
                // Se está aguardando usuário, mostrar ícone de pausa
                if (solicitacao.status?.toLowerCase() ==
                    'aguardando usuario') ...[
                  Icon(
                    Icons.pause_circle_outline,
                    size: 12,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SLA pausado',
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: _isPrazoAtrasado(solicitacao.prazo!)
                        ? AppColors.error
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    solicitacao.prazo!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _isPrazoAtrasado(solicitacao.prazo!)
                          ? AppColors.error
                          : AppColors.textTertiary,
                      fontWeight: _isPrazoAtrasado(solicitacao.prazo!)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ],
              const Spacer(),
              if (solicitacao.nomeAcessor != null)
                Text(
                  solicitacao.nomeAcessor!.split(' ').first,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isPrazoAtrasado(String prazo) {
    try {
      final prazoDate = DateFormat('dd/MM/yyyy').parse(prazo);
      return prazoDate.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  final String prioridade;

  const _PriorityBadge({required this.prioridade});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (prioridade.toLowerCase()) {
      case 'alta':
        color = AppColors.error;
        icon = Icons.keyboard_arrow_up;
        break;
      case 'média':
      case 'media':
        color = AppColors.warning;
        icon = Icons.remove;
        break;
      case 'baixa':
      default:
        color = AppColors.textTertiary;
        icon = Icons.keyboard_arrow_down;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            prioridade,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
