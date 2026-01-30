import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notificacao_providers.dart';

/// Badge de notificações com sino e contador
class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(notificacoesNaoLidasCountProvider);

    return countAsync.when(
      data: (count) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.bell),
              onPressed: () => context.go('/notificacoes'),
              tooltip: 'Notificações',
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => IconButton(
        icon: const Icon(LucideIcons.bell),
        onPressed: () => context.go('/notificacoes'),
        tooltip: 'Notificações',
      ),
      error: (_, __) => IconButton(
        icon: const Icon(LucideIcons.bell),
        onPressed: () => context.go('/notificacoes'),
        tooltip: 'Notificações',
      ),
    );
  }
}
