import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/solicitacao.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Widget de visualização em lista das solicitações
class SolicitacoesListView extends StatelessWidget {
  final List<Solicitacao> solicitacoes;
  final Function(Solicitacao)? onTap;
  final Function(Solicitacao, SolicitacaoStatus)? onStatusChange;
  final bool isLoading;

  const SolicitacoesListView({
    super.key,
    required this.solicitacoes,
    this.onTap,
    this.onStatusChange,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (solicitacoes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.inbox,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma solicitação encontrada',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'ID',
                    style: _headerStyle,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text('Título', style: _headerStyle),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Cidadão', style: _headerStyle),
                ),
                SizedBox(
                  width: 130,
                  child: Text('Status', style: _headerStyle),
                ),
                SizedBox(
                  width: 90,
                  child: Text('Prioridade', style: _headerStyle),
                ),
                SizedBox(
                  width: 100,
                  child: Text('Prazo', style: _headerStyle),
                ),
                SizedBox(
                  width: 140,
                  child: Text('Assessor', style: _headerStyle),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              itemCount: solicitacoes.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final sol = solicitacoes[index];
                return _SolicitacaoListItem(
                  solicitacao: sol,
                  onTap: () => onTap?.call(sol),
                  onStatusChange: (status) => onStatusChange?.call(sol, status),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );
}

class _SolicitacaoListItem extends StatelessWidget {
  final Solicitacao solicitacao;
  final VoidCallback? onTap;
  final Function(SolicitacaoStatus)? onStatusChange;

  const _SolicitacaoListItem({
    required this.solicitacao,
    this.onTap,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // ID
              SizedBox(
                width: 50,
                child: Text(
                  '#${solicitacao.id}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Título
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitacao.titulo ?? 'Sem título',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (solicitacao.categoria != null)
                      Text(
                        solicitacao.categoria!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Cidadão
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CachedAvatar(
                      radius: 14,
                      imageUrl: solicitacao.cidadao?.foto,
                      name: solicitacao.cidadao?.nome,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        solicitacao.cidadao?.nome ?? 'Cidadão não identificado',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: solicitacao.cidadao?.nome == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: solicitacao.cidadao?.nome == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              SizedBox(
                width: 130,
                child: _StatusDropdown(
                  currentStatus: solicitacao.statusEnum,
                  onChanged: onStatusChange,
                ),
              ),

              // Prioridade
              SizedBox(
                width: 90,
                child: _PriorityBadge(
                    prioridade: solicitacao.prioridade ?? 'Média'),
              ),

              // Prazo
              SizedBox(
                width: 100,
                child: Text(
                  solicitacao.prazo ?? '-',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isPrazoAtrasado(solicitacao.prazo)
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: _isPrazoAtrasado(solicitacao.prazo)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),

              // Assessor
              SizedBox(
                width: 140,
                child: Text(
                  solicitacao.nomeAcessor ?? '-',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPrazoAtrasado(String? prazo) {
    if (prazo == null) return false;
    try {
      final prazoDate = DateFormat('dd/MM/yyyy').parse(prazo);
      return prazoDate.isBefore(DateTime.now()) &&
          solicitacao.status?.toLowerCase() != 'finalizado';
    } catch (_) {
      return false;
    }
  }
}

class _StatusDropdown extends StatelessWidget {
  final SolicitacaoStatus currentStatus;
  final Function(SolicitacaoStatus)? onChanged;

  const _StatusDropdown({
    required this.currentStatus,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SolicitacaoStatus>(
      initialValue: currentStatus,
      onSelected: onChanged,
      tooltip: 'Alterar status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: currentStatus.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: currentStatus.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentStatus.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                currentStatus.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: currentStatus.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: currentStatus.color,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => SolicitacaoStatus.values.map((status) {
        return PopupMenuItem(
          value: status,
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
              const SizedBox(width: 8),
              Text(status.label),
            ],
          ),
        );
      }).toList(),
    );
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
