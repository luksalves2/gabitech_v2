import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/cidadao_providers.dart';
import '../../../providers/solicitacao_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../data/models/cidadao.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/cached_avatar.dart';
import '../../widgets/cidadao_form_dialog.dart';
import 'package:showcaseview/showcaseview.dart';

/// Enum for tabs
enum CidadaoTab { cadastrados, aniversarios, distribuicoes }

/// State providers
final _selectedTabProvider =
    StateProvider<CidadaoTab>((ref) => CidadaoTab.cadastrados);
final _searchProvider = StateProvider<String>((ref) => '');
final _currentPageProvider = StateProvider<int>((ref) => 0);
const _pageSize = 20;

/// Provider para métricas de cidadãos
final _cidadaosMetricsProvider =
    FutureProvider.autoDispose<_CidadaosMetrics>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) {
    return _CidadaosMetrics(
      totalCadastrados: 0,
      pendentes: 0,
      aniversariantes: 0,
      comSolicitacoesAbertas: 0,
    );
  }

  // Busca todos os cidadãos para métricas
  final allCidadaos = await ref.watch(
    cidadaosProvider(const CidadaosParams(limit: 1000)).future,
  );
  final cidadaosDoGabinete =
      allCidadaos.where((c) => c.gabinete == null || c.gabinete == gabinete.id).toList();

  // Busca todas as solicitações abertas
  final solicitacoesKanban = await ref.watch(
    solicitacoesKanbanProvider(const SolicitacoesParams()).future,
  );

  // Calcula métricas
  final now = DateTime.now();
  int totalCadastrados = 0;
  int pendentes = 0;
  int aniversariantes = 0;
  final cidadaosComSolicitacao = <int>{};

  for (final cidadao in cidadaosDoGabinete) {
    // Verifica se está cadastrado (tem endereço)
    if (cidadao.bairro != null && cidadao.bairro!.isNotEmpty) {
      totalCadastrados++;
    } else {
      pendentes++;
    }

    // Verifica se é aniversariante do mês
    if (cidadao.dataNascimento != null) {
      try {
        DateTime? date;
        if (cidadao.dataNascimento!.contains('/')) {
          final parts = cidadao.dataNascimento!.split('/');
          if (parts.length >= 2) {
            final month = int.tryParse(parts[1]);
            if (month == now.month) aniversariantes++;
          }
        } else {
          date = DateTime.tryParse(cidadao.dataNascimento!);
          if (date != null && date.month == now.month) aniversariantes++;
        }
      } catch (_) {}
    }
  }

  // Conta cidadãos com solicitações abertas
  for (final entry in solicitacoesKanban.entries) {
    // Ignora status "Concluído" e "Cancelado"
    if (entry.key.toLowerCase() != 'concluído' &&
        entry.key.toLowerCase() != 'cancelado') {
      for (final sol in entry.value) {
        if (sol.cidadaoId != null &&
            (sol.gabinete == null || sol.gabinete == gabinete.id)) {
          cidadaosComSolicitacao.add(sol.cidadaoId!);
        }
      }
    }
  }

  return _CidadaosMetrics(
    totalCadastrados: totalCadastrados,
    pendentes: pendentes,
    aniversariantes: aniversariantes,
    comSolicitacoesAbertas: cidadaosComSolicitacao.length,
  );
});

class _CidadaosMetrics {
  final int totalCadastrados;
  final int pendentes;
  final int aniversariantes;
  final int comSolicitacoesAbertas;

  _CidadaosMetrics({
    required this.totalCadastrados,
    required this.pendentes,
    required this.aniversariantes,
    required this.comSolicitacoesAbertas,
  });
}

class CidadaosPage extends ConsumerStatefulWidget {
  const CidadaosPage({super.key});

  @override
  ConsumerState<CidadaosPage> createState() => _CidadaosPageState();
}

class _CidadaosPageState extends ConsumerState<CidadaosPage> {
  final _searchController = TextEditingController();

  // Tutorial keys
  final _tourRefreshKey = GlobalKey();
  final _tourMetricasKey = GlobalKey();
  final _tourTabsKey = GlobalKey();
  final _tourBuscaKey = GlobalKey();
  final _tourNovoKey = GlobalKey();
  final _tourAniversariosHeaderKey = GlobalKey();
  final _tourAniversariosParabenizarKey = GlobalKey();
  final _tourDistribKpisKey = GlobalKey();
  final _tourDistribBairroKey = GlobalKey();
  final _tourDistribFaixaGeneroKey = GlobalKey();
  final _tourDistribPerfilEnderecoKey = GlobalKey();

  final ShowcaseView _showcase = ShowcaseView.register();
  bool _tourRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'cidadaos';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(_selectedTabProvider);

    return ShowCaseWidget(
      blurValue: 1,
      builder: (context) => MainLayout(
        title: 'Cidadãos',
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.playCircle),
            tooltip: 'Rever tutorial',
            onPressed: _startTour,
          ),
          const SizedBox(width: 4),
          // Refresh button
          Showcase(
            key: _tourRefreshKey,
            title: 'Atualizar lista',
            description: 'Recarrega métricas e dados das abas.',
            child: IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: _refreshData,
              tooltip: 'Atualizar',
            ),
          ),
        ],
        floatingActionButton: selectedTab == CidadaoTab.cadastrados
            ? Showcase(
                key: _tourNovoKey,
                title: 'Novo cidadão',
                description: 'Abra o formulário para cadastrar rapidamente.',
                child: FloatingActionButton.extended(
                  onPressed: () => _showCreateCidadaoDrawer(context),
                  icon: const Icon(LucideIcons.userPlus),
                  label: const Text('Novo Cidadão'),
                  backgroundColor: AppColors.primary,
                ),
              )
            : null,
        child: Column(
          children: [
            // Metrics cards
            Showcase(
              key: _tourMetricasKey,
              title: 'Painel de métricas',
              description: 'Visão geral de cadastros, pendentes e aniversariantes.',
              child: _buildMetricsSection(),
            ),
            const SizedBox(height: 16),
            // Tabs
            Showcase(
              key: _tourTabsKey,
              title: 'Abas de navegação',
              description: 'Alterne entre lista, aniversariantes e distribuições.',
              child: _buildTabs(),
            ),
            const SizedBox(height: 20),
            // Content
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final selectedTab = ref.watch(_selectedTabProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabButton(
            icon: LucideIcons.users,
            label: 'Cadastrados',
            isSelected: selectedTab == CidadaoTab.cadastrados,
            onTap: () => ref.read(_selectedTabProvider.notifier).state =
                CidadaoTab.cadastrados,
          ),
          _TabButton(
            icon: LucideIcons.cake,
            label: 'Aniversários',
            isSelected: selectedTab == CidadaoTab.aniversarios,
            onTap: () => ref.read(_selectedTabProvider.notifier).state =
                CidadaoTab.aniversarios,
          ),
          _TabButton(
            icon: LucideIcons.pieChart,
            label: 'Distribuições',
            isSelected: selectedTab == CidadaoTab.distribuicoes,
            onTap: () => ref.read(_selectedTabProvider.notifier).state =
                CidadaoTab.distribuicoes,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    final metricsAsync = ref.watch(_cidadaosMetricsProvider);

    return metricsAsync.when(
      data: (metrics) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: LucideIcons.userCheck,
                label: 'Cadastros completos',
                value: '${metrics.totalCadastrados}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: LucideIcons.userPlus,
                label: 'Pendentes cadastro',
                value: '${metrics.pendentes}',
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: LucideIcons.cake,
                label: 'Aniversariantes',
                value: '${metrics.aniversariantes}',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: LucideIcons.clipboardList,
                label: 'Com solicitações',
                value: '${metrics.comSolicitacoesAbertas}',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: List.generate(
              4,
              (_) => Expanded(
                    child: Container(
                      height: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final selectedTab = ref.watch(_selectedTabProvider);

    switch (selectedTab) {
      case CidadaoTab.cadastrados:
        return _buildCadastradosTab();
      case CidadaoTab.aniversarios:
        return _buildAniversariosTab();
      case CidadaoTab.distribuicoes:
        return _buildDistribuicoesTab();
    }
  }

  // ===== CADASTRADOS TAB =====
  Widget _buildCadastradosTab() {
    final searchTerm = ref.watch(_searchProvider);
    final currentPage = ref.watch(_currentPageProvider);

    final cidadaosAsync = ref.watch(
      cidadaosProvider(CidadaosParams(
        limit: _pageSize,
        offset: currentPage * _pageSize,
        searchTerm: searchTerm.isNotEmpty ? searchTerm : null,
      )),
    );

    return cidadaosAsync.when(
      data: (cidadaos) => _buildCadastradosList(cidadaos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState('cidadãos'),
    );
  }

  Widget _buildCadastradosList(List<Cidadao> cidadaos) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Search and stats bar
          Showcase(
            key: _tourBuscaKey,
            title: 'Buscar e paginar',
            description: 'Pesquise por nome/contato e avance páginas.',
            child: _buildSearchAndStatsBar(cidadaos.length),
          ),
          const SizedBox(height: 20),

          if (cidadaos.isEmpty)
            SizedBox(
              height: 300,
              child: _buildEmptyState(
                  'Nenhum cidadão cadastrado', LucideIcons.users),
            )
          else
            _buildCidadaosListView(cidadaos),
        ],
      ),
    );
  }

  Widget _buildSearchAndStatsBar(int count) {
    final currentPage = ref.watch(_currentPageProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              onChanged: (value) {
                ref.read(_searchProvider.notifier).state = value;
                ref.read(_currentPageProvider.notifier).state = 0;
              },
            ),
          ),
          const SizedBox(width: 24),
          // Stats
          Text(
            '$count cidadãos',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          // Pagination
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
            onPressed: currentPage > 0
                ? () => ref.read(_currentPageProvider.notifier).state--
                : null,
          ),
          Text('Página ${currentPage + 1}'),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 20),
            onPressed: count >= _pageSize
                ? () => ref.read(_currentPageProvider.notifier).state++
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCidadaosListView(List<Cidadao> cidadaos) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 48), // Avatar space
                Expanded(flex: 3, child: Text('Nome', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Telefone', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Email', style: _headerStyle)),
                Expanded(flex: 2, child: Text('Endereço', style: _headerStyle)),
                const SizedBox(width: 80), // Actions space
              ],
            ),
          ),
          // Rows
          ...cidadaos.map((cidadao) => _CidadaoListRow(
                cidadao: cidadao,
                onTap: () => _showCidadaoDetails(context, cidadao),
                onEdit: () => _showEditCidadaoDialog(context, cidadao),
              )),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: AppColors.textSecondary,
      );

  // ===== PRÉ-CADASTRADOS TAB =====
  // ignore: unused_element
  Widget _buildPreCadastradosTab() {
    final cidadaosAsync = ref.watch(
      cidadaosProvider(CidadaosParams(
        limit: 100,
        status: 'pre-cadastro',
      )),
    );

    return cidadaosAsync.when(
      data: (cidadaos) => _buildPreCadastradosList(cidadaos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState('pré-cadastrados'),
    );
  }

  Widget _buildPreCadastradosList(List<Cidadao> cidadaos) {
    if (cidadaos.isEmpty) {
      return _buildEmptyState(
        'Nenhum contato pré-cadastrado',
        LucideIcons.userPlus,
        subtitle: 'Contatos do WhatsApp ainda não atendidos aparecerão aqui',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estes são contatos que chegaram via WhatsApp mas ainda não foram atendidos. '
                    'Complete o cadastro para movê-los para a lista de cidadãos.',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
          // List
          ...cidadaos.map((c) => _PreCadastradoCard(
                cidadao: c,
                onComplete: () => _completeCadastro(c),
              )),
        ],
      ),
    );
  }

  // ===== ANIVERSÁRIOS TAB =====
  Widget _buildAniversariosTab() {
    final gabineteAsync = ref.watch(currentGabineteProvider);

    return gabineteAsync.when(
      data: (gabinete) {
        if (gabinete == null) {
          return _buildErrorState('gabinete');
        }

        final cidadaosAsync = ref.watch(
          cidadaosProvider(const CidadaosParams(limit: 100)),
        );

        return cidadaosAsync.when(
          data: (cidadaos) {
            final filtrados = cidadaos
                .where((c) => c.gabinete == null || c.gabinete == gabinete.id)
                .toList();
            final aniversariantes = _filterAniversariantes(filtrados);
            return _buildAniversariosList(aniversariantes);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorState('aniversariantes'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState('gabinete'),
    );
  }

  List<Cidadao> _filterAniversariantes(List<Cidadao> cidadaos) {
    final now = DateTime.now();
    return cidadaos.where((c) {
      if (c.dataNascimento == null) return false;
      try {
        // Tenta parse de diferentes formatos
        DateTime? date;
        if (c.dataNascimento!.contains('/')) {
          final parts = c.dataNascimento!.split('/');
          if (parts.length >= 2) {
            final month = int.tryParse(parts[1]);
            return month == now.month;
          }
        } else {
          date = DateTime.tryParse(c.dataNascimento!);
          if (date != null) return date.month == now.month;
        }
        return false;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Widget _buildAniversariosList(List<Cidadao> cidadaos) {
    final now = DateTime.now();
    final mesAtual = _getNomeMes(now.month);

    if (cidadaos.isEmpty) {
      return _buildEmptyState(
        'Nenhum aniversariante em $mesAtual',
        LucideIcons.cake,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Showcase(
            key: _tourAniversariosHeaderKey,
            title: 'Visão dos aniversariantes',
            description:
                'Veja quem faz aniversário no mês atual e quantos cidadãos serão notificados.',
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.cake,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aniversariantes de $mesAtual',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '${cidadaos.length} cidadão(s) fazem aniversário este mês',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // List
          ...cidadaos.asMap().entries.map((entry) {
            final c = entry.value;
            final card = _AniversarianteCard(
              cidadao: c,
              onParabenizar: () => _parabenizar(c),
            );

            // Destaca apenas o primeiro card para o passo do tour
            if (entry.key == 0) {
              return Showcase(
                key: _tourAniversariosParabenizarKey,
                title: 'Parabenizar rapidamente',
                description:
                    'Use o atalho para enviar felicitações ao aniversariante diretamente.',
                child: card,
              );
            }

            return card;
          }),
        ],
      ),
    );
  }

  // ===== DISTRIBUIÇÕES TAB =====
  Widget _buildDistribuicoesTab() {
    final gabineteAsync = ref.watch(currentGabineteProvider);

    return gabineteAsync.when(
      data: (gabinete) {
        if (gabinete == null) {
          return _buildErrorState('gabinete');
        }

        final cidadaosAsync = ref.watch(
          cidadaosProvider(const CidadaosParams(limit: 1000)),
        );

        return cidadaosAsync.when(
          data: (cidadaos) {
            final filtrados = cidadaos
                .where((c) => c.gabinete == null || c.gabinete == gabinete.id)
                .toList();
            return _buildDistribuicoesContent(filtrados);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorState('distribuições'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState('gabinete'),
    );
  }

  Widget _buildDistribuicoesContent(List<Cidadao> cidadaos) {
    final distribuicoes = _calcularDistribuicoes(cidadaos);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // KPIs
          Showcase(
            key: _tourDistribKpisKey,
            title: 'Indicadores rápidos',
            description:
                'Resumo de total de cidadãos, pendências de endereço e média de idade.',
            child: Row(
              children: [
                Expanded(
                    child: _MetricCard(
                  label: 'Total de cidadãos',
                  value: '${distribuicoes.total}',
                  icon: LucideIcons.users,
                  color: AppColors.primary,
                )),
                const SizedBox(width: 16),
                Expanded(
                    child: _MetricCard(
                  label: 'Sem endereço',
                  value: '${distribuicoes.semEndereco}',
                  icon: LucideIcons.mapPinOff,
                  color: AppColors.warning,
                )),
                const SizedBox(width: 16),
                Expanded(
                    child: _MetricCard(
                  label: 'Média de idade',
                  value: '${distribuicoes.mediaIdade} anos',
                  icon: LucideIcons.calendar,
                  color: AppColors.secondary,
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cidadãos por bairro
          Showcase(
            key: _tourDistribBairroKey,
            title: 'Mapa por bairro',
            description:
                'Compare rapidamente onde estão concentrados os cadastros.',
            child: _buildBairroChart(distribuicoes.porBairro),
          ),
          const SizedBox(height: 24),

          // Row with two charts
          Showcase(
            key: _tourDistribFaixaGeneroKey,
            title: 'Faixa etária e gênero',
            description:
                'Use estes gráficos para identificar perfis demográficos rapidamente.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Faixa etária
                Expanded(
                    child:
                        _buildFaixaEtariaChart(distribuicoes.porFaixaEtaria)),
                const SizedBox(width: 24),
                // Gênero
                Expanded(child: _buildGeneroChart(distribuicoes.porGenero)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Row with two more charts
          Showcase(
            key: _tourDistribPerfilEnderecoKey,
            title: 'Perfil e endereços',
            description:
                'Verifique rapidamente tipos de perfil e quem ainda precisa de endereço.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Perfil
                Expanded(child: _buildPerfilChart(distribuicoes.porPerfil)),
                const SizedBox(width: 24),
                // Endereço
                Expanded(child: _buildEnderecoChart(distribuicoes.porEndereco)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  _CidadaoDistribuicoes _calcularDistribuicoes(List<Cidadao> cidadaos) {
    final porBairro = <String, int>{};
    final porGenero = <String, int>{};
    final porPerfil = <String, int>{};
    final porFaixaEtaria = <String, int>{
      '0-17': 0,
      '18-29': 0,
      '30-44': 0,
      '45-59': 0,
      '60+': 0,
    };

    int totalIdades = 0;
    int countIdades = 0;
    int semEndereco = 0;
    final porEndereco = <String, int>{};

    for (final c in cidadaos) {
      // Bairro
      final bairro = c.bairro ?? 'Não informado';
      porBairro[bairro] = (porBairro[bairro] ?? 0) + 1;

      // Gênero
      final genero = c.genero ?? 'Não informado';
      porGenero[genero] = (porGenero[genero] ?? 0) + 1;

      // Perfil
      final perfil = c.perfil ?? 'Não informado';
      porPerfil[perfil] = (porPerfil[perfil] ?? 0) + 1;

      // Status
      // Verifica se tem endereço completo
      final temEndereco = c.bairro != null && c.bairro!.isNotEmpty &&
                          c.rua != null && c.rua!.isNotEmpty;
      if (temEndereco) {
        porEndereco['Com endereço'] = (porEndereco['Com endereço'] ?? 0) + 1;
      } else {
        porEndereco['Sem endereço'] = (porEndereco['Sem endereço'] ?? 0) + 1;
        semEndereco++;
      }

      // Idade
      if (c.dataNascimento != null) {
        final idade = _calcularIdade(c.dataNascimento!);
        if (idade != null) {
          totalIdades += idade;
          countIdades++;

          if (idade < 18) {
            porFaixaEtaria['0-17'] = porFaixaEtaria['0-17']! + 1;
          } else if (idade < 30) {
            porFaixaEtaria['18-29'] = porFaixaEtaria['18-29']! + 1;
          } else if (idade < 45) {
            porFaixaEtaria['30-44'] = porFaixaEtaria['30-44']! + 1;
          } else if (idade < 60) {
            porFaixaEtaria['45-59'] = porFaixaEtaria['45-59']! + 1;
          } else {
            porFaixaEtaria['60+'] = porFaixaEtaria['60+']! + 1;
          }
        }
      }
    }

    return _CidadaoDistribuicoes(
      total: cidadaos.length,
      semEndereco: semEndereco,
      mediaIdade: countIdades > 0 ? (totalIdades / countIdades).round() : 0,
      porBairro: porBairro,
      porFaixaEtaria: porFaixaEtaria,
      porGenero: porGenero,
      porPerfil: porPerfil,
      porEndereco: porEndereco,
    );
  }

  int? _calcularIdade(String dataNascimento) {
    try {
      DateTime? date;
      if (dataNascimento.contains('/')) {
        final parts = dataNascimento.split('/');
        if (parts.length == 3) {
          date = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } else {
        date = DateTime.tryParse(dataNascimento);
      }

      if (date == null) return null;

      final now = DateTime.now();
      int idade = now.year - date.year;
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        idade--;
      }
      return idade;
    } catch (_) {
      return null;
    }
  }

  Widget _buildBairroChart(Map<String, int> data) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = sortedEntries.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Cidadãos por bairro',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (top10.isEmpty)
            Center(
              child: Text(
                'Sem dados disponíveis',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...top10.map((entry) => _buildBarChartRow(
                  entry.key,
                  entry.value,
                  sortedEntries.first.value,
                  AppColors.primary,
                )),
        ],
      ),
    );
  }

  Widget _buildBarChartRow(String label, int value, int maxValue, Color color) {
    final percentage = maxValue > 0 ? value / maxValue : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.isNotEmpty ? label : 'Não informado',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaixaEtariaChart(Map<String, int> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.users, size: 20, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Cidadãos por Faixa Etária',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: data.values.every((v) => v == 0)
                ? Center(
                    child: Text('Sem dados',
                        style: TextStyle(color: AppColors.textSecondary)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.values
                              .fold(0, (a, b) => a > b ? a : b)
                              .toDouble() *
                          1.2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = data.keys.toList();
                              if (value.toInt() < keys.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    keys[value.toInt()],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      barGroups:
                          data.entries.toList().asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.value.toDouble(),
                              color: Colors.purple,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneroChart(Map<String, int> data) {
    final colors = [Colors.pink, Colors.blue, Colors.purple, Colors.teal];
    final total = data.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.users, size: 20, color: Colors.pink),
              const SizedBox(width: 8),
              Text(
                'Cidadãos por Gênero',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: total == 0
                ? Center(
                    child: Text('Sem dados',
                        style: TextStyle(color: AppColors.textSecondary)))
                : PieChart(
                    PieChartData(
                      sections:
                          data.entries.toList().asMap().entries.map((entry) {
                        final percentage =
                            total > 0 ? (entry.value.value / total * 100) : 0;
                        return PieChartSectionData(
                          value: entry.value.value.toDouble(),
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: colors[entry.key % colors.length],
                          radius: 50,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: data.entries.toList().asMap().entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[entry.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(entry.value.key.isNotEmpty
                      ? entry.value.key
                      : 'Não informado'),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.value.value}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilChart(Map<String, int> data) {
    final maxValue = data.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.tag, size: 20, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'Cidadãos por Perfil',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            Center(
              child: Text('Sem dados disponíveis',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...data.entries.take(8).map((entry) => _buildBarChartRow(
                  entry.key,
                  entry.value,
                  maxValue,
                  AppColors.success,
                )),
        ],
      ),
    );
  }

  Widget _buildEnderecoChart(Map<String, int> data) {
    final maxValue = data.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 20, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                'Cidadãos por Endereço',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (data.isEmpty)
            Center(
              child: Text('Sem dados disponíveis',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...data.entries.map((entry) => _buildBarChartRow(
                  entry.key,
                  entry.value,
                  maxValue,
                  entry.key == 'Com endereço' ? AppColors.success : AppColors.warning,
                )),
        ],
      ),
    );
  }

  // ===== HELPER METHODS =====
  Widget _buildEmptyState(String message, IconData icon, {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String item) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Erro ao carregar $item'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _refreshData,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  void _refreshData() {
    ref.invalidate(cidadaosProvider);
  }

  void _showCidadaoDetails(BuildContext context, Cidadao cidadao) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CidadaoDetailsSheet(cidadao: cidadao),
    );
  }

  void _showCreateCidadaoDrawer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CidadaoFormDialog(
        onSaved: (cidadao) {
          _refreshData();
          ref.invalidate(_cidadaosMetricsProvider);
        },
      ),
    );
  }

  void _showEditCidadaoDialog(BuildContext context, Cidadao cidadao) {
    showDialog(
      context: context,
      builder: (context) => CidadaoFormDialog(
        cidadao: cidadao,
        onSaved: (updatedCidadao) {
          _refreshData();
          ref.invalidate(_cidadaosMetricsProvider);
        },
      ),
    );
  }

  void _completeCadastro(Cidadao cidadao) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Completar cadastro de ${cidadao.nome}')),
    );
  }

  void _parabenizar(Cidadao cidadao) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Parabenizar ${cidadao.nome} - Em breve!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _startTour() {
    if (_tourRunning) return;
    _tourRunning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedTab = ref.read(_selectedTabProvider);

      // Passos comuns a todas as abas
      final steps = [
        _tourRefreshKey,
        _tourMetricasKey,
        _tourTabsKey,
      ];

      // Passos específicos para cada aba
      switch (selectedTab) {
        case CidadaoTab.cadastrados:
          steps.addAll([
            _tourBuscaKey,
            _tourNovoKey,
          ]);
          break;
        case CidadaoTab.aniversarios:
          steps.addAll([
            _tourAniversariosHeaderKey,
            _tourAniversariosParabenizarKey,
          ]);
          break;
        case CidadaoTab.distribuicoes:
          steps.addAll([
            _tourDistribKpisKey,
            _tourDistribBairroKey,
            _tourDistribFaixaGeneroKey,
            _tourDistribPerfilEnderecoKey,
          ]);
          break;
      }

      _showcase.startShowCase(steps);
      _tourRunning = false;
    });
  }

  String _getNomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return meses[mes - 1];
  }
}

// ===== WIDGETS =====

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CidadaoListRow extends StatelessWidget {
  final Cidadao cidadao;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const _CidadaoListRow({required this.cidadao, this.onTap, this.onEdit});

  /// Formata o número de telefone removendo @s.whatsapp.net e formatando visualmente
  String _formatTelefone(String? telefone) {
    if (telefone == null || telefone.isEmpty) return '-';

    // Remove @s.whatsapp.net se existir
    String numero =
        telefone.replaceAll('@s.whatsapp.net', '').replaceAll('@c.us', '');

    // Remove caracteres não numéricos
    numero = numero.replaceAll(RegExp(r'[^0-9]'), '');

    if (numero.isEmpty) return '-';

    // Formato brasileiro: +55 (XX) XXXXX-XXXX ou +55 (XX) XXXX-XXXX
    if (numero.length >= 12 && numero.startsWith('55')) {
      final ddd = numero.substring(2, 4);
      final resto = numero.substring(4);
      if (resto.length == 9) {
        return '+55 ($ddd) ${resto.substring(0, 5)}-${resto.substring(5)}';
      } else if (resto.length == 8) {
        return '+55 ($ddd) ${resto.substring(0, 4)}-${resto.substring(4)}';
      }
    } else if (numero.length == 11) {
      // DDD + 9 dígitos
      return '(${numero.substring(0, 2)}) ${numero.substring(2, 7)}-${numero.substring(7)}';
    } else if (numero.length == 10) {
      // DDD + 8 dígitos
      return '(${numero.substring(0, 2)}) ${numero.substring(2, 6)}-${numero.substring(6)}';
    }

    return numero;
  }

  @override
  Widget build(BuildContext context) {
    final nomeExibicao = (cidadao.nome == null || cidadao.nome!.isEmpty)
        ? 'Aguardando cadastro'
        : cidadao.nome!;
    final isNomePendente = cidadao.nome == null || cidadao.nome!.isEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            CachedAvatar(
              radius: 20,
              imageUrl: cidadao.foto,
              name: cidadao.nome,
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeExibicao,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          isNomePendente ? FontStyle.italic : FontStyle.normal,
                      color: isNomePendente ? AppColors.textTertiary : null,
                    ),
                  ),
                  if (cidadao.perfil != null)
                    Text(cidadao.perfil!,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(_formatTelefone(cidadao.telefone),
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (cidadao.email == null || cidadao.email!.isEmpty)
                    ? 'Não informado'
                    : cidadao.email!,
                style: TextStyle(
                  color: (cidadao.email == null || cidadao.email!.isEmpty)
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                  fontStyle: (cidadao.email == null || cidadao.email!.isEmpty)
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (cidadao.bairro == null || cidadao.bairro!.isEmpty)
                    ? 'Não informado'
                    : cidadao.bairro!,
                style: TextStyle(
                  color: (cidadao.bairro == null || cidadao.bairro!.isEmpty)
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                  fontStyle: (cidadao.bairro == null || cidadao.bairro!.isEmpty)
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.eye, size: 18),
                    onPressed: onTap,
                    tooltip: 'Ver detalhes',
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.edit, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Editar',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreCadastradoCard extends StatelessWidget {
  final Cidadao cidadao;
  final VoidCallback onComplete;

  const _PreCadastradoCard({required this.cidadao, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.warning.withValues(alpha: 0.1),
            child: Text(
              cidadao.nome?.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cidadao.nome ?? 'Contato',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Icon(LucideIcons.phone,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(cidadao.telefone ?? '-',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onComplete,
            icon: const Icon(LucideIcons.userCheck, size: 16),
            label: const Text('Completar Cadastro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AniversarianteCard extends StatelessWidget {
  final Cidadao cidadao;
  final VoidCallback onParabenizar;

  const _AniversarianteCard(
      {required this.cidadao, required this.onParabenizar});

  @override
  Widget build(BuildContext context) {
    final diaAniversario = _getDiaAniversario(cidadao.dataNascimento);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CachedAvatar(
                radius: 28,
                imageUrl: cidadao.foto,
                name: cidadao.nome,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.cake,
                      size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cidadao.nome ?? 'Cidadão',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Dia $diaAniversario',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onParabenizar,
            icon: const Icon(LucideIcons.partyPopper, size: 16),
            label: const Text('Parabenizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _getDiaAniversario(String? dataNascimento) {
    if (dataNascimento == null) return '?';
    try {
      if (dataNascimento.contains('/')) {
        final parts = dataNascimento.split('/');
        if (parts.isNotEmpty) return parts[0];
      }
      final date = DateTime.tryParse(dataNascimento);
      if (date != null) return date.day.toString().padLeft(2, '0');
      return '?';
    } catch (_) {
      return '?';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

class _CidadaoDetailsSheet extends StatelessWidget {
  final Cidadao cidadao;

  const _CidadaoDetailsSheet({required this.cidadao});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.chevronLeft),
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cidadao.nome ?? 'Cidadão',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Avatar and basic info
                    CachedAvatar(
                      radius: 48,
                      imageUrl: cidadao.foto,
                      name: cidadao.nome,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      cidadao.nome ?? 'Cidadão',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (cidadao.perfil != null)
                      Text(cidadao.perfil!,
                          style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    // Info items
                    _DetailItem(
                        icon: LucideIcons.phone,
                        label: 'Telefone',
                        value: cidadao.telefone ?? '-'),
                    _DetailItem(
                        icon: LucideIcons.mail,
                        label: 'E-mail',
                        value: cidadao.email ?? '-'),
                    _DetailItem(
                        icon: LucideIcons.mapPin,
                        label: 'Bairro',
                        value: cidadao.bairro ?? '-'),
                    _DetailItem(
                        icon: LucideIcons.calendar,
                        label: 'Nascimento',
                        value: cidadao.dataNascimento ?? '-'),
                    _DetailItem(
                        icon: LucideIcons.user,
                        label: 'Gênero',
                        value: cidadao.genero ?? '-'),
                    const SizedBox(height: 24),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.clipboardList),
                            label: const Text('Ver Solicitações'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.edit),
                            label: const Text('Editar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Model for distribuições data
class _CidadaoDistribuicoes {
  final int total;
  final int semEndereco;
  final int mediaIdade;
  final Map<String, int> porBairro;
  final Map<String, int> porFaixaEtaria;
  final Map<String, int> porGenero;
  final Map<String, int> porPerfil;
  final Map<String, int> porEndereco;

  _CidadaoDistribuicoes({
    required this.total,
    required this.semEndereco,
    required this.mediaIdade,
    required this.porBairro,
    required this.porFaixaEtaria,
    required this.porGenero,
    required this.porPerfil,
    required this.porEndereco,
  });
}
