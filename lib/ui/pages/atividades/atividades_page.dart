import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models/tarefa.dart';
import '../../../data/models/solicitacao.dart';
import '../../../providers/tarefa_providers.dart';
import '../../../providers/solicitacao_providers.dart';
import '../../../providers/core_providers.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/solicitacao_details_dialog.dart';

/// Provider for search term
final _searchProvider = StateProvider<String>((ref) => '');

/// Provider for status filter (null = todas, 'pendente', 'concluida')
final _statusFilterProvider = StateProvider<String?>((ref) => null);

/// Provider for all atividades from gabinete with solicitacao info
final _atividadesWithSolicitacaoProvider = FutureProvider.autoDispose<
    List<({Tarefa atividade, Solicitacao? solicitacao})>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  // Get all atividades
  final atividades = await ref.watch(atividadesByGabineteProvider.future);

  // Get all solicitacoes for lookup
  final solicitacoes = await ref.watch(
    solicitacoesListProvider(const SolicitacoesParams()).future,
  );

  // Map atividades with their solicitacao
  return atividades.map((atividade) {
    final Solicitacao? solicitacao = solicitacoes
        .where((s) => s.id == atividade.solicitacao)
        .firstOrNull;
    return (atividade: atividade, solicitacao: solicitacao);
  }).toList();
});

class AtividadesPage extends ConsumerStatefulWidget {
  const AtividadesPage({super.key});

  @override
  ConsumerState<AtividadesPage> createState() => _AtividadesPageState();
}

class _AtividadesPageState extends ConsumerState<AtividadesPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'atividades';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atividadesAsync = ref.watch(_atividadesWithSolicitacaoProvider);

    return MainLayout(
      title: 'Atividades',
      child: Column(
        children: [
          // Metrics
          _buildMetrics(atividadesAsync),

          // Content area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  // Toolbar
                  _buildToolbar(),

                  const Divider(height: 1),

                  // Content
                  Expanded(
                    child: _buildAtividadesList(atividadesAsync),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(
    AsyncValue<List<({Tarefa atividade, Solicitacao? solicitacao})>>
        atividadesAsync,
  ) {
    return atividadesAsync.when(
      data: (atividades) {
        final total = atividades.length;
        final pendentes =
            atividades.where((a) => a.atividade.status != 'concluida').length;
        final concluidas =
            atividades.where((a) => a.atividade.status == 'concluida').length;
        final solicitacoesCount =
            atividades.map((a) => a.atividade.solicitacao).toSet().length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Total',
                  value: total.toString(),
                  icon: LucideIcons.listChecks,
                  iconColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: 'Pendentes',
                  value: pendentes.toString(),
                  icon: LucideIcons.circle,
                  iconColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: 'Concluídas',
                  value: concluidas.toString(),
                  icon: LucideIcons.checkCircle2,
                  iconColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: 'Solicitações',
                  value: solicitacoesCount.toString(),
                  icon: LucideIcons.clipboardList,
                  iconColor: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(height: 80),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildToolbar() {
    final statusFilter = ref.watch(_statusFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar atividade ou solicitação...',
                hintStyle:
                    TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: Icon(LucideIcons.search,
                    size: 18, color: AppColors.textSecondary),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                ref.read(_searchProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(width: 16),

          // Status filter
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todas',
                  isSelected: statusFilter == null,
                  onTap: () =>
                      ref.read(_statusFilterProvider.notifier).state = null,
                ),
                _FilterChip(
                  label: 'Pendentes',
                  isSelected: statusFilter == 'pendente',
                  onTap: () => ref.read(_statusFilterProvider.notifier).state =
                      'pendente',
                ),
                _FilterChip(
                  label: 'Concluídas',
                  isSelected: statusFilter == 'concluida',
                  onTap: () => ref.read(_statusFilterProvider.notifier).state =
                      'concluida',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtividadesList(
    AsyncValue<List<({Tarefa atividade, Solicitacao? solicitacao})>>
        atividadesAsync,
  ) {
    final searchTerm = ref.watch(_searchProvider);
    final statusFilter = ref.watch(_statusFilterProvider);

    return atividadesAsync.when(
      data: (atividades) {
        var filtered = atividades.toList();

        // Filter by search
        if (searchTerm.isNotEmpty) {
          filtered = filtered.where((a) {
            final atividadeMatch = a.atividade.titulo
                    ?.toLowerCase()
                    .contains(searchTerm.toLowerCase()) ==
                true;
            final solicitacaoMatch = a.solicitacao?.titulo
                    ?.toLowerCase()
                    .contains(searchTerm.toLowerCase()) ==
                true;
            return atividadeMatch || solicitacaoMatch;
          }).toList();
        }

        // Filter by status
        if (statusFilter != null) {
          if (statusFilter == 'pendente') {
            filtered = filtered
                .where((a) => a.atividade.status != 'concluida')
                .toList();
          } else if (statusFilter == 'concluida') {
            filtered = filtered
                .where((a) => a.atividade.status == 'concluida')
                .toList();
          }
        }

        // Sort: pendentes first, then by date
        filtered.sort((a, b) {
          final aIsPendente = a.atividade.status != 'concluida';
          final bIsPendente = b.atividade.status != 'concluida';
          if (aIsPendente && !bIsPendente) return -1;
          if (!aIsPendente && bIsPendente) return 1;
          return (b.atividade.createdAt ?? DateTime.now())
              .compareTo(a.atividade.createdAt ?? DateTime.now());
        });

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.checkCircle2,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  statusFilter == 'pendente'
                      ? 'Nenhuma atividade pendente'
                      : statusFilter == 'concluida'
                          ? 'Nenhuma atividade concluída'
                          : 'Nenhuma atividade encontrada',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                if (statusFilter == 'pendente') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Todas as atividades foram concluídas!',
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _AtividadeCard(
              atividade: item.atividade,
              solicitacao: item.solicitacao,
              onTap: () => _openSolicitacao(item.solicitacao),
              onStatusChange: () {
                final newStatus =
                    item.atividade.status == 'concluida' ? 'pendente' : 'concluida';
                ref.read(tarefaNotifierProvider.notifier).updateStatus(
                      item.atividade.id,
                      item.atividade.solicitacao ?? 0,
                      newStatus,
                    );
                // Refresh the list
                ref.invalidate(_atividadesWithSolicitacaoProvider);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erro ao carregar atividades: $e',
            style: TextStyle(color: AppColors.error)),
      ),
    );
  }

  void _openSolicitacao(Solicitacao? solicitacao) {
    if (solicitacao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Esta atividade não está vinculada a uma solicitação'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SolicitacaoDetailsDialog(solicitacao: solicitacao),
    );
  }
}

// ============================================
// WIDGETS
// ============================================

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AtividadeCard extends StatelessWidget {
  final Tarefa atividade;
  final Solicitacao? solicitacao;
  final VoidCallback onTap;
  final VoidCallback onStatusChange;

  const _AtividadeCard({
    required this.atividade,
    this.solicitacao,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final isConcluida = atividade.status == 'concluida';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isConcluida
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConcluida
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Checkbox - using GestureDetector to not interfere with parent InkWell
              GestureDetector(
                onTap: onStatusChange,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isConcluida ? AppColors.success : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isConcluida ? AppColors.success : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isConcluida
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Atividade title
                  Text(
                    atividade.titulo ?? 'Sem título',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isConcluida
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration:
                          isConcluida ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (atividade.descricao != null &&
                      atividade.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      atividade.descricao!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Solicitação info
                  if (solicitacao != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.clipboardList,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            solicitacao!.titulo ?? 'Solicitação #${solicitacao!.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (solicitacao!.categoria != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              solicitacao!.categoria!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
