import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/core_providers.dart';
import '../theme/app_colors.dart';

/// Selected menu item state
final selectedMenuProvider = StateProvider<String>((ref) => 'home');

/// Sidebar widget - optimized to not refetch user data
class AppSidebar extends ConsumerWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMenu = ref.watch(selectedMenuProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      LucideIcons.building2,
                      size: 48,
                      color: Colors.grey,
                    );
                  },
                ),
              ),
            ),
          ),
          
          const Divider(height: 1),
          
          // Menu items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.layoutDashboard,
                    label: 'Dashboard',
                    route: 'home',
                    isSelected: selectedMenu == 'home',
                    hasPermission: currentUser.value?.dashboard ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.clipboardList,
                    label: 'Solicitações',
                    route: 'solicitacoes',
                    isSelected: selectedMenu == 'solicitacoes',
                    hasPermission: currentUser.value?.solicitacoes ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.users,
                    label: 'Cidadãos',
                    route: 'cidadaos',
                    isSelected: selectedMenu == 'cidadaos',
                    hasPermission: currentUser.value?.cidadaos ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.mapPin,
                    label: 'Geolocalização',
                    route: 'cidadaos-map',
                    isSelected: selectedMenu == 'cidadaos-map',
                    hasPermission: currentUser.value?.cidadaos ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.checkSquare,
                    label: 'Atividades',
                    route: 'atividades',
                    isSelected: selectedMenu == 'atividades',
                    hasPermission: currentUser.value?.atividades ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.send,
                    label: 'Transmissões',
                    route: 'transmissoes',
                    isSelected: selectedMenu == 'transmissoes',
                    hasPermission: currentUser.value?.transmissoes ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.messageSquare,
                    label: 'Mensagens',
                    route: 'mensagens',
                    isSelected: selectedMenu == 'mensagens',
                    hasPermission: currentUser.value?.atendimento ?? true,
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.userCog,
                    label: 'Assessores',
                    route: 'acessores',
                    isSelected: selectedMenu == 'acessores',
                    hasPermission: currentUser.value?.acessores ?? true,
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.bell,
                    label: 'Notificações',
                    route: 'notificacoes',
                    isSelected: selectedMenu == 'notificacoes',
                  ),
                  _buildMenuItem(
                    context: context,
                    ref: ref,
                    icon: LucideIcons.user,
                    label: 'Perfil',
                    route: 'perfil',
                    isSelected: selectedMenu == 'perfil',
                  ),
                ],
              ),
            ),
          ),
          
          // User info at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: currentUser.when(
              data: (user) => Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    backgroundImage: user?.avatar != null
                        ? NetworkImage(user!.avatar!)
                        : null,
                    child: user?.avatar == null
                        ? Text(
                            user?.nome?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nome ?? 'Usuário',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.cargo ?? 'Assessor',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).signOut();
                    },
                    tooltip: 'Sair',
                  ),
                ],
              ),
              loading: () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required String route,
    required bool isSelected,
    bool hasPermission = true,
  }) {
    if (!hasPermission) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              ref.read(selectedMenuProvider.notifier).state = route;
              // Navigate to the route
              context.goNamed(route);
            },
            child: Semantics(
              button: true,
              selected: isSelected,
              label: label,
              onTapHint: 'Abrir $label',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
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
