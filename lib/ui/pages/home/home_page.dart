import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/mensagem_providers.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/weekly_chart.dart';
import '../../widgets/birthday_card.dart';
import '../../widgets/dashboard_mini_lists.dart';
import '../../widgets/app_sidebar.dart';
import 'package:showcaseview/showcaseview.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _welcomeKey = GlobalKey();
  final _refreshKey = GlobalKey();
  final _kpiNovasKey = GlobalKey();
  final _chartKey = GlobalKey();
  final _birthdayKey = GlobalKey();
  final _atrasadasKey = GlobalKey();
  final ShowcaseView _showcase = ShowcaseView.register();
  bool _tourStarted = false;

  @override
  void initState() {
    super.initState();
    // Set menu state and clear dashboard cache so navigation always shows fresh data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'home';
      ref.read(dashboardRepositoryProvider).clearCache();
      ref.invalidate(dashboardProvider);
    });
  }

  void _startTour() {
    if (_tourStarted) return;
    _tourStarted = true;
    Future.delayed(const Duration(milliseconds: 300), () {
      _showcase.startShowCase([
        _welcomeKey,
        _refreshKey,
        _kpiNovasKey,
        _chartKey,
        _birthdayKey,
        _atrasadasKey,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final currentUser = ref.watch(currentUserProvider);

    return ShowCaseWidget(
      blurValue: 1,
      builder: (context) => MainLayout(
          title: 'Dashboard',
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.playCircle),
              tooltip: 'Rever tutorial',
              onPressed: () {
                _tourStarted = false;
                _startTour();
              },
            ),
            Showcase(
              key: _refreshKey,
              title: 'Atualizar dados',
              description: 'Recarrega métricas e listas em tempo real.',
              child: IconButton(
                icon: const Icon(LucideIcons.refreshCw),
                onPressed: () {
                  ref.read(dashboardRepositoryProvider).clearCache();
                  ref.invalidate(dashboardProvider);
                },
                tooltip: 'Atualizar',
              ),
            ),
          ],
          child: RefreshIndicator(
            onRefresh: () async {
              ref.read(dashboardRepositoryProvider).clearCache();
              ref.invalidate(dashboardProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  Showcase(
                    key: _welcomeKey,
                    title: 'Boas‑vindas',
                    description:
                        'Aqui você vê um resumo rápido do seu gabinete ao entrar.',
                    child: currentUser.when(
                      data: (user) => RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.headlineMedium,
                          children: [
                            const TextSpan(text: 'Bem vindo ao '),
                            TextSpan(
                              text: 'Gabitech',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user?.nome != null)
                              TextSpan(text: ', ${user!.nome!.split(' ').first}'),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Acompanhe os atendimentos do seu gabinete',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // KPI Cards - 2 linhas de 3 cards
                  dashboard.when(
                    data: (data) => LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        final isMedium = constraints.maxWidth > 600;
                        
                        return Column(
                          children: [
                            // Primeira linha: 3 cards principais
                            _buildKpiRow(
                              isWide: isWide,
                              isMedium: isMedium,
                              children: [
                                Showcase(
                                  key: _kpiNovasKey,
                                  title: 'Novas solicitações',
                                  description:
                                      'Entradas recentes que chegaram hoje.',
                                  child: KpiCard(
                                    title: 'Novas Solicitações',
                                    value: '${data.novasSolicitacoes}',
                                    icon: LucideIcons.messageSquare,
                                    gradient: AppColors.blueGradient,
                                  ),
                                ),
                                KpiCard(
                                  title: 'Conversas Finalizadas',
                                  value: '${data.conversasFinalizadas}',
                                  icon: LucideIcons.checkCircle2,
                                  gradient: AppColors.greenGradient,
                                ),
                                KpiCard(
                                  title: 'Em Atendimento',
                                  value: '${data.emAtendimento}',
                                  icon: LucideIcons.messageCircle,
                                  gradient: AppColors.yellowGradient,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Segunda linha: 3 cards secundários
                            _buildKpiRow(
                              isWide: isWide,
                              isMedium: isMedium,
                              children: [
                                KpiCard(
                                  title: 'Cidadãos Cadastrados',
                                  value: '${data.cidadaosCadastrados}',
                                  icon: LucideIcons.users,
                                  gradient: AppColors.lightBlueGradient,
                                ),
                                KpiCard(
                                  title: 'Solicitações Atrasadas',
                                  value: '${data.solicitacoesAtrasadas}',
                                  icon: LucideIcons.alertCircle,
                                  gradient: AppColors.redGradient,
                                ),
                                KpiCard(
                                  title: 'Solicitações Semanais',
                                  value: '${data.solicitacoesSemanais}',
                                  icon: LucideIcons.calendar,
                                  gradient: AppColors.orangeGradient,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.alertCircle,
                              size: 48,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erro ao carregar dados',
                              style: TextStyle(color: AppColors.error),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => ref.invalidate(dashboardProvider),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Gráfico semanal e Aniversariantes
                  dashboard.when(
                    data: (data) => LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gráfico semanal
                              Expanded(
                                flex: 2,
                                child: Showcase(
                                  key: _chartKey,
                                  title: 'Volume semanal',
                                  description:
                                      'Visualize a evolução das solicitações por dia da semana.',
                                  child: WeeklyChart(data: data.chartData),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Aniversariantes
                              Expanded(
                                flex: 1,
                                child: Showcase(
                                  key: _birthdayKey,
                                  title: 'Aniversariantes',
                                  description:
                                      'Lista de cidadãos que fazem aniversário no período.',
                                  child: BirthdayCard(
                                      aniversariantes: data.aniversariantes),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Showcase(
                                key: _chartKey,
                                title: 'Volume semanal',
                                description:
                                    'Visualize a evolução das solicitações por dia da semana.',
                                child: WeeklyChart(data: data.chartData),
                              ),
                              const SizedBox(height: 20),
                              Showcase(
                                key: _birthdayKey,
                                title: 'Aniversariantes',
                                description:
                                    'Lista de cidadãos que fazem aniversário no período.',
                                child: BirthdayCard(
                                    aniversariantes: data.aniversariantes),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // Mini-listas: Atrasadas e Conversas aguardando
                  dashboard.when(
                    data: (data) => LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Showcase(
                                  key: _atrasadasKey,
                                  title: 'Solicitações atrasadas',
                                  description:
                                      'Aqui ficam as pendências que já passaram do prazo.',
                                  child:
                                      AtrasadasMiniList(items: data.listaAtrasadas),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: ConversasAguardandoMiniList(
                                    items: data.listaConversasAguardando,
                                    onItemTap: (conversa) async {
                                      final atendimento = await ref.read(
                                        atendimentoProvider(conversa.id).future,
                                      );
                                      if (atendimento != null && context.mounted) {
                                        ref.read(selectedAtendimentoProvider.notifier).state = atendimento;
                                        context.go('/mensagens');
                                      }
                                    },
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Showcase(
                                key: _atrasadasKey,
                                title: 'Solicitações atrasadas',
                                description:
                                    'Aqui ficam as pendências que já passaram do prazo.',
                                child:
                                    AtrasadasMiniList(items: data.listaAtrasadas),
                              ),
                              const SizedBox(height: 20),
                              ConversasAguardandoMiniList(
                                  items: data.listaConversasAguardando,
                                  onItemTap: (conversa) async {
                                    final atendimento = await ref.read(
                                      atendimentoProvider(conversa.id).future,
                                    );
                                    if (atendimento != null && context.mounted) {
                                      ref.read(selectedAtendimentoProvider.notifier).state = atendimento;
                                      context.go('/mensagens');
                                    }
                                  },
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildKpiRow({
    required bool isWide,
    required bool isMedium,
    required List<Widget> children,
  }) {
    if (isWide) {
      // 3 colunas
      return Row(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index > 0 ? 10 : 0,
                right: index < children.length - 1 ? 10 : 0,
              ),
              child: SizedBox(height: 130, child: child),
            ),
          );
        }).toList(),
      );
    } else if (isMedium) {
      // 2 + 1 layout
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(height: 130, child: children[0]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(height: 130, child: children[1]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 130, child: children[2]),
        ],
      );
    } else {
      // 1 coluna
      return Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < children.length - 1 ? 20 : 0),
            child: SizedBox(height: 130, child: child),
          );
        }).toList(),
      );
    }
  }
}
