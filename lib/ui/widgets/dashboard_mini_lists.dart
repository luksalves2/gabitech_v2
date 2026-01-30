import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../data/models/dashboard_data.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Mini-lista de solicitações atrasadas
class AtrasadasMiniList extends StatelessWidget {
  final List<SolicitacaoResumo> items;

  const AtrasadasMiniList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return _DashboardMiniCard(
      icon: LucideIcons.alertTriangle,
      iconColor: AppColors.error,
      iconBgColor: const Color(0xFFFEF2F2),
      title: 'Solicitações Atrasadas',
      subtitle: '${items.length} pendentes',
      emptyIcon: LucideIcons.checkCircle2,
      emptyText: 'Nenhuma solicitação atrasada',
      child: items.isEmpty
          ? null
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _AtrasadaItem(item: item);
              },
            ),
    );
  }
}

class _AtrasadaItem extends StatelessWidget {
  final SolicitacaoResumo item;

  const _AtrasadaItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final diasAtraso = _calcDiasAtraso(item.prazo);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(LucideIcons.clock, size: 18, color: AppColors.error),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.cidadaoNome ?? 'Cidadao nao vinculado',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diasAtraso > 0 ? '${diasAtraso}d atraso' : 'Vencido',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calcDiasAtraso(String? prazo) {
    if (prazo == null) return 0;
    DateTime? prazoDate;
    try {
      prazoDate = DateFormat('dd/MM/yyyy').parse(prazo);
    } catch (_) {
      try {
        prazoDate = DateTime.parse(prazo);
      } catch (_) {
        return 0;
      }
    }
    return DateTime.now().difference(prazoDate).inDays;
  }
}

/// Mini-lista de conversas aguardando resposta
class ConversasAguardandoMiniList extends StatelessWidget {
  final List<ConversaAguardando> items;
  final void Function(ConversaAguardando item)? onItemTap;

  const ConversasAguardandoMiniList({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardMiniCard(
      icon: LucideIcons.messageCircle,
      iconColor: AppColors.warning,
      iconBgColor: const Color(0xFFFFFBEB),
      title: 'Aguardando Resposta',
      subtitle: '${items.length} conversas',
      emptyIcon: LucideIcons.messageSquare,
      emptyText: 'Nenhuma conversa aguardando',
      child: items.isEmpty
          ? null
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ConversaItem(
                  item: item,
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                );
              },
            ),
    );
  }
}

class _ConversaItem extends StatelessWidget {
  final ConversaAguardando item;
  final VoidCallback? onTap;

  const _ConversaItem({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tempoEspera = _tempoEspera(item.ultimaMensagemEm);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CachedAvatar(
            radius: 18,
            imageUrl: item.foto,
            name: item.cidadaoNome,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.cidadaoNome ?? _formatPhone(item.telefone),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.ultimaMensagem != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.ultimaMensagem!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (tempoEspera != null) ...[
            const SizedBox(width: 8),
            Text(
              tempoEspera,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  String? _tempoEspera(DateTime? dt) {
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _formatPhone(String? raw) {
    if (raw == null) return 'Desconhecido';
    var phone = raw.replaceAll(RegExp(r'@.*$'), '');
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.startsWith('55') && phone.length >= 12) {
      phone = phone.substring(2);
    }
    if (phone.length == 11) {
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 7)}-${phone.substring(7)}';
    } else if (phone.length == 10) {
      return '(${phone.substring(0, 2)}) ${phone.substring(2, 6)}-${phone.substring(6)}';
    }
    return phone;
  }
}

/// Card container reutilizável para as mini-listas
class _DashboardMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final IconData emptyIcon;
  final String emptyText;
  final Widget? child;

  const _DashboardMiniCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.emptyIcon,
    required this.emptyText,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (child != null)
            child!
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    emptyIcon,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyText,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
