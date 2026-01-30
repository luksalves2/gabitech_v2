import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/dashboard_data.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Widget de aniversariantes da semana
class BirthdayCard extends StatelessWidget {
  final List<Aniversariante> aniversariantes;
  final String title;
  final String subtitle;

  const BirthdayCard({
    super.key,
    required this.aniversariantes,
    this.title = 'Aniversariantes',
    this.subtitle = 'Esta semana',
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
                  color: const Color(0xFFFDF2F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🎂',
                  style: TextStyle(fontSize: 20),
                ),
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
          if (aniversariantes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    LucideIcons.cake,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum aniversariante esta semana',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: aniversariantes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final aniversariante = aniversariantes[index];
                return _AniversarianteItem(aniversariante: aniversariante);
              },
            ),
        ],
      ),
    );
  }
}

class _AniversarianteItem extends StatelessWidget {
  final Aniversariante aniversariante;

  const _AniversarianteItem({required this.aniversariante});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final anivEsteAno = DateTime(
      now.year,
      aniversariante.dataNascimento.month,
      aniversariante.dataNascimento.day,
    );
    final isToday = now.day == anivEsteAno.day && now.month == anivEsteAno.month;
    final daysDiff = anivEsteAno.difference(now).inDays;
    
    String subtitleText;
    if (isToday) {
      subtitleText = '🎉 Hoje!';
    } else if (daysDiff == 1) {
      subtitleText = 'Amanhã';
    } else if (daysDiff > 0) {
      subtitleText = 'Em $daysDiff dias';
    } else {
      subtitleText = DateFormat('dd/MM').format(anivEsteAno);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          CachedAvatar(
            radius: 20,
            imageUrl: aniversariante.foto,
            name: aniversariante.nome,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aniversariante.nome,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitleText,
                  style: TextStyle(
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('dd/MM').format(anivEsteAno),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
