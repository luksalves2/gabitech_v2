import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../data/models/solicitacao.dart';
import '../../../providers/solicitacao_providers.dart';
import '../../../providers/tarefa_providers.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/kanban_column_drag_drop.dart';
import '../../widgets/solicitacoes_list_view.dart';
import '../../widgets/create_solicitacao_dialog.dart';
import '../../widgets/solicitacao_details_dialog.dart';
import '../../widgets/categoria_management_dialog.dart';
import 'package:showcaseview/showcaseview.dart';

/// Tipo de visualização
enum ViewType { kanban, list }

/// Provider para o tipo de visualização
final _viewTypeProvider = StateProvider<ViewType>((ref) => ViewType.kanban);

/// Provider para busca
final _searchProvider = StateProvider<String>((ref) => '');

/// Provider para filtro de categoria
final _categoriaFilterProvider = StateProvider<int?>((ref) => null);

class SolicitacoesPage extends ConsumerStatefulWidget {
  const SolicitacoesPage({super.key});

  @override
  ConsumerState<SolicitacoesPage> createState() => _SolicitacoesPageState();
}

class _SolicitacoesPageState extends ConsumerState<SolicitacoesPage> {
  final _searchController = TextEditingController();
  final _kanbanScrollController = ScrollController();

  // Tutorial keys
  final _tourSearchKey = GlobalKey();
  final _tourViewKey = GlobalKey();
  final _tourRefreshKey = GlobalKey();
  final _tourNovaKey = GlobalKey();
  final _tourMetricasKey = GlobalKey();
  final _tourBoardKey = GlobalKey();

  final ShowcaseView _showcase = ShowcaseView.register();
  bool _tourRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'solicitacoes';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _kanbanScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewType = ref.watch(_viewTypeProvider);
    final searchTerm = ref.watch(_searchProvider);
    final categoriaId = ref.watch(_categoriaFilterProvider);

    return ShowCaseWidget(
      blurValue: 1,
      builder: (context) => MainLayout(
        title: 'Solicitações',
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.playCircle),
            tooltip: 'Rever tutorial',
            onPressed: _startTour,
          ),
          const SizedBox(width: 4),

          // Search field
          Showcase(
            key: _tourSearchKey,
            title: 'Buscar solicitações',
            description: 'Filtre por título, descrição ou acessor.',
            child: SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar solicitação...',
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                onChanged: (value) {
                  ref.read(_searchProvider.notifier).state = value;
                },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Category filter
          _buildCategoriaFilter(),
          const SizedBox(width: 4),

          // Manage categories button
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const CategoriaManagementDialog(),
            ),
            icon: Icon(LucideIcons.settings2, size: 18),
            tooltip: 'Gerenciar Categorias',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),

          // View toggle
          Showcase(
            key: _tourViewKey,
            title: 'Alternar visualização',
            description: 'Troque entre Kanban e Lista rapidamente.',
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _ViewToggleButton(
                    icon: LucideIcons.layoutGrid,
                    isSelected: viewType == ViewType.kanban,
                    onTap: () => ref.read(_viewTypeProvider.notifier).state =
                        ViewType.kanban,
                    tooltip: 'Kanban',
                  ),
                  _ViewToggleButton(
                    icon: LucideIcons.list,
                    isSelected: viewType == ViewType.list,
                    onTap: () =>
                        ref.read(_viewTypeProvider.notifier).state = ViewType.list,
                    tooltip: 'Lista',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Refresh button
          Showcase(
            key: _tourRefreshKey,
            title: 'Atualizar dados',
            description: 'Recarrega o Kanban e a lista com dados mais recentes.',
            child: IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              onPressed: () {
                ref.invalidate(solicitacoesKanbanProvider);
                ref.invalidate(solicitacoesListProvider);
              },
              tooltip: 'Atualizar',
            ),
          ),
          const SizedBox(width: 8),

          // New solicitação button
          Showcase(
            key: _tourNovaKey,
            title: 'Criar solicitação',
            description: 'Abra o formulário e registre uma nova demanda.',
            child: ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Nova Solicitação'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
        child: viewType == ViewType.kanban
            ? _buildKanbanView(searchTerm, categoriaId)
            : _buildListView(searchTerm, categoriaId),
      ),
    );
  }

  Widget _buildKanbanView(String searchTerm, int? categoriaId) {
    final solicitacoesAsync = ref.watch(
      solicitacoesKanbanProvider(SolicitacoesParams(
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
        categoriaId: categoriaId,
      )),
    );

    return solicitacoesAsync.when(
      data: (grouped) => Column(
        children: [
          // Metrics bar
          Showcase(
            key: _tourMetricasKey,
            title: 'Métricas rápidas',
            description: 'Veja contagem por status, atrasos e prioridades.',
            child: _buildMetricsBar(grouped),
          ),
          // Kanban board
          Expanded(
            child: Showcase(
              key: _tourBoardKey,
              title: 'Quadro Kanban',
              description:
                  'Arraste entre colunas. \"Em atraso\" é automático e só sai para \"Finalizado\".',
              child: _buildKanbanBoard(context, grouped),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorWidget(),
    );
  }

  Widget _buildListView(String searchTerm, int? categoriaId) {
    final solicitacoesAsync = ref.watch(
      solicitacoesListProvider(SolicitacoesParams(
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
        categoriaId: categoriaId,
      )),
    );

    // Também precisamos do grouped para as métricas
    final kanbanAsync = ref.watch(
      solicitacoesKanbanProvider(SolicitacoesParams(
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
        categoriaId: categoriaId,
      )),
    );

    return Column(
      children: [
        // Metrics bar (usa o kanban provider para ter os dados agrupados)
        kanbanAsync.when(
          data: (grouped) => _buildMetricsBar(grouped),
          loading: () => const SizedBox(height: 80),
          error: (_, __) => const SizedBox(height: 80),
        ),
        // List view
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: solicitacoesAsync.when(
              data: (solicitacoes) => Showcase(
                key: _tourBoardKey,
                title: 'Lista de solicitações',
                description:
                    'Toque para ver detalhes ou altere o status direto na lista.',
                child: SolicitacoesListView(
                  solicitacoes: solicitacoes,
                  onTap: (sol) => _showSolicitacaoDetails(context, sol),
                  onStatusChange: (sol, status) =>
                      _updateStatus(sol.id, status.value),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanBoard(
      BuildContext context, Map<String, List<Solicitacao>> grouped) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ScrollConfiguration(
        // Permite scroll via trackpad/touch, mas desabilita mouse drag
        // para não conflitar com drag and drop dos cards
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _kanbanScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _kanbanScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: SolicitacaoStatus.values.map((status) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height - 260,
                  child: KanbanColumnDragDrop(
                    status: status,
                    solicitacoes: grouped[status.value] ?? [],
                    onCardTap: (sol) => _showSolicitacaoDetails(context, sol),
                    onStatusChange: (sol, newStatus) =>
                        _updateStatus(sol.id, newStatus.value),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsBar(Map<String, List<Solicitacao>> grouped) {
    // Calcular métricas
    final allSolicitacoes = grouped.values.expand((list) => list).toList();
    final total = allSolicitacoes.length;
    final finalizados = grouped['finalizado']?.length ?? 0;
    final emAtraso = grouped['em atraso']?.length ?? 0;
    final emAndamento = grouped['em andamento']?.length ?? 0;
    final emAnalise = grouped['em analise']?.length ?? 0;
    final aguardandoUsuario = grouped['aguardando usuario']?.length ?? 0;

    // Calcular taxa de conclusão
    final taxaConclusao =
        total > 0 ? (finalizados / total * 100).toStringAsFixed(0) : '0';

    // Calcular solicitações próximas do prazo (7 dias) - excluindo aguardando usuario
    final hoje = DateTime.now();
    final hojeDia = DateTime(hoje.year, hoje.month, hoje.day);
    int proximasVencer = 0;
    for (final sol in allSolicitacoes) {
      if (sol.prazo != null &&
          sol.status != 'finalizado' &&
          sol.status != 'aguardando usuario') {
        DateTime? prazoDate;
        try {
          prazoDate = DateFormat('dd/MM/yyyy').parse(sol.prazo!);
        } catch (_) {
          try {
            prazoDate = DateTime.parse(sol.prazo!);
          } catch (_) {}
        }
        if (prazoDate != null) {
          final prazoDia = DateTime(prazoDate.year, prazoDate.month, prazoDate.day);
          final diasRestantes = prazoDia.difference(hojeDia).inDays;
          if (diasRestantes >= 0 && diasRestantes <= 7) {
            proximasVencer++;
          }
        }
      }
    }

    // Calcular por prioridade (excluindo finalizados e aguardando)
    final altaPrioridade = allSolicitacoes
        .where((s) =>
            s.prioridade?.toLowerCase() == 'alta' &&
            s.status != 'finalizado' &&
            s.status != 'aguardando usuario')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se tela for muito pequena, usar scroll horizontal
          if (constraints.maxWidth < 900) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildMetricCards(
                  total: total,
                  emAndamento: emAndamento,
                  emAnalise: emAnalise,
                  aguardandoUsuario: aguardandoUsuario,
                  finalizados: finalizados,
                  taxaConclusao: taxaConclusao,
                  emAtraso: emAtraso,
                  proximasVencer: proximasVencer,
                  altaPrioridade: altaPrioridade,
                  useFixedWidth: true,
                ),
              ),
            );
          }
          
          // Tela grande: usar layout responsivo com Expanded
          return Row(
            children: _buildMetricCards(
              total: total,
              emAndamento: emAndamento,
              emAnalise: emAnalise,
              aguardandoUsuario: aguardandoUsuario,
              finalizados: finalizados,
              taxaConclusao: taxaConclusao,
              emAtraso: emAtraso,
              proximasVencer: proximasVencer,
              altaPrioridade: altaPrioridade,
              useFixedWidth: false,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMetricCards({
    required int total,
    required int emAndamento,
    required int emAnalise,
    required int aguardandoUsuario,
    required int finalizados,
    required String taxaConclusao,
    required int emAtraso,
    required int proximasVencer,
    required int altaPrioridade,
    required bool useFixedWidth,
  }) {
    Widget wrapCard(_MetricCard card) {
      if (useFixedWidth) return card;
      return Expanded(child: card);
    }
    
    Widget spacer() {
      return const SizedBox(width: 12);
    }
    
    return [
      wrapCard(_MetricCard(
        icon: LucideIcons.fileText,
        iconColor: AppColors.primary,
        label: 'Total',
        value: total.toString(),
        subtitle: 'solicitações',
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.loader,
        iconColor: SolicitacaoStatus.emAndamento.color,
        label: 'Em Andamento',
        value: emAndamento.toString(),
        subtitle: emAnalise > 0 ? '+$emAnalise em análise' : 'ativas',
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.userCheck,
        iconColor: SolicitacaoStatus.aguardandoUsuario.color,
        label: 'Aguardando',
        value: aguardandoUsuario.toString(),
        subtitle: 'SLA pausado',
        isHighlight: aguardandoUsuario > 0,
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.checkCircle,
        iconColor: SolicitacaoStatus.finalizado.color,
        label: 'Finalizadas',
        value: finalizados.toString(),
        subtitle: '$taxaConclusao% do total',
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.alertTriangle,
        iconColor: SolicitacaoStatus.emAtraso.color,
        label: 'Em Atraso',
        value: emAtraso.toString(),
        subtitle: emAtraso > 0 ? 'Atenção!' : 'Nenhuma',
        isWarning: emAtraso > 0,
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.clock,
        iconColor: Colors.orange,
        label: 'Vence em 7d',
        value: proximasVencer.toString(),
        subtitle: 'próximas',
        isWarning: proximasVencer > 0,
        useFixedWidth: useFixedWidth,
      )),
      spacer(),
      wrapCard(_MetricCard(
        icon: LucideIcons.flame,
        iconColor: Colors.red.shade400,
        label: 'Prioridade Alta',
        value: altaPrioridade.toString(),
        subtitle: 'pendentes',
        isWarning: altaPrioridade > 3,
        useFixedWidth: useFixedWidth,
      )),
    ];
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar solicitações',
            style: TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.invalidate(solicitacoesKanbanProvider);
              ref.invalidate(solicitacoesListProvider);
            },
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(int id, String status) {
    ref.read(solicitacaoNotifierProvider.notifier).updateStatus(id, status);
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateSolicitacaoDialog(),
    );
  }

  void _showSolicitacaoDetails(BuildContext context, Solicitacao sol) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SolicitacaoDetailsDialog(solicitacao: sol),
    );
  }

  void _startTour() {
    if (_tourRunning) return;
    _tourRunning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showcase.startShowCase([
        _tourSearchKey,
        _tourViewKey,
        _tourRefreshKey,
        _tourNovaKey,
        _tourMetricasKey,
        _tourBoardKey,
      ]);
      _tourRunning = false;
    });
  }

  Widget _buildCategoriaFilter() {
    final categoriasAsync = ref.watch(categoriasTarefasProvider);
    final selectedCategoria = ref.watch(_categoriaFilterProvider);

    return categoriasAsync.when(
      data: (categorias) {
        if (categorias.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedCategoria,
              hint: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.filter, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Categoria',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              icon: Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              dropdownColor: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todas', style: TextStyle(color: AppColors.textPrimary)),
                ),
                ...categorias.map((cat) => DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _parseColor(cat.cor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(cat.nome),
                    ],
                  ),
                )),
              ],
              onChanged: (value) {
                ref.read(_categoriaFilterProvider.notifier).state = value;
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 100,
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return AppColors.primary;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final bool isWarning;
  final bool isHighlight;
  final bool useFixedWidth;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.isWarning = false,
    this.isHighlight = false,
    this.useFixedWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final showAccent = isWarning || isHighlight;

    return Container(
      width: useFixedWidth ? 145 : null,
      constraints: useFixedWidth ? null : const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: showAccent ? iconColor.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: showAccent ? iconColor.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: showAccent ? iconColor : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 8,
                      color: showAccent
                          ? iconColor.withValues(alpha: 0.8)
                          : AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
