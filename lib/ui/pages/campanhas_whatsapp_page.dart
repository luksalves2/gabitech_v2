import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../providers/core_providers.dart';
import '../../providers/transmissao_providers.dart';
import '../../data/models/cidadao.dart';
import '../../providers/cidadao_providers.dart';
import '../layouts/main_layout.dart';
import '../widgets/app_sidebar.dart';

/// Tela de Campanhas WhatsApp — versão corrigida e com estruturas no nível superior
class CampanhasWhatsappPage extends ConsumerStatefulWidget {
  const CampanhasWhatsappPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CampanhasWhatsappPage> createState() =>
      _CampanhasWhatsappPageState();
}

class _CampanhasWhatsappPageState extends ConsumerState<CampanhasWhatsappPage> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'Todas';
  DateTimeRange? _dateRange;
  String _bairroFilter = 'Todos';
  String _perfilFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedMenuProvider.notifier).state = 'transmissoes';
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCriarCampanha() async {
    try {
      final result = await showDialog<bool>(
          context: context, builder: (_) => CriarCampanhaDialog());
      if (!mounted) return;
      if (result == true) {
        ref.invalidate(transmissoesProvider);
      }
    } catch (e, st) {
      // Report error to user for debugging
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao abrir diálogo: $e')));
      // Also print stack for logs
      // ignore: avoid_print
      print('Erro ao abrir CriarCampanhaDialog: $e\n$st');
    }
  }

  void _openDetalhes(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bairros =
            (c['bairros'] as List<dynamic>? ?? []).map((e) => e.toString());
        final perfis =
            (c['perfil'] as List<dynamic>? ?? []).map((e) => e.toString());
        final categorias =
            (c['categorias'] as List<dynamic>? ?? []).map((e) => e.toString());
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DefaultTabController(
            length: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detalhes da transmissão',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Resumo'),
                      Tab(text: 'Cidadãos'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DetailRow(
                                  label: 'Título', value: c['titulo'] ?? '-'),
                              _DetailRow(
                                  label: 'Status', value: c['status'] ?? '-'),
                              _DetailRow(
                                  label: 'Data', value: c['data'] ?? '-'),
                              _DetailRow(
                                  label: 'Hora', value: c['hora'] ?? '-'),
                              _DetailRow(
                                  label: 'Mensagem', value: c['mensagem'] ?? '-'),
                              _DetailRow(
                                  label: 'Gênero',
                                  value: c['genero'] ?? 'Todos'),
                              _DetailRow(
                                  label: 'Bairros',
                                  value:
                                      bairros.isEmpty ? '-' : bairros.join(', ')),
                              _DetailRow(
                                  label: 'Perfis',
                                  value:
                                      perfis.isEmpty ? '-' : perfis.join(', ')),
                              _DetailRow(
                                  label: 'Categorias',
                                  value: categorias.isEmpty
                                      ? '-'
                                      : categorias.join(', ')),
                              Consumer(
                                builder: (context, ref, _) {
                                  final raw =
                                      ref.watch(cidadaosMapRawProvider).valueOrNull ??
                                          [];
                                  final targets =
                                      raw.where((cid) => _matchesTransmissao(cid, c)).toList();
                                  return _DetailRow(
                                    label: 'Alvos estimados',
                                    value: targets.length.toString(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final raw =
                                ref.watch(cidadaosMapRawProvider).valueOrNull ??
                                    [];
                            final targets =
                                raw.where((cid) => _matchesTransmissao(cid, c)).toList();
                            if (targets.isEmpty) {
                              return Center(
                                child: Text(
                                  'Nenhum cidadão corresponde aos filtros.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              );
                            }
                            return ListView.separated(
                              itemCount: targets.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, i) {
                                final cid = targets[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueGrey.shade50,
                                    child: Text(
                                      (cid.nome ?? 'C')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(cid.nome ?? 'Sem nome'),
                                  subtitle: Text(
                                    [
                                      cid.telefone,
                                      cid.bairro,
                                      cid.perfil,
                                    ].where((e) => e != null && e!.isNotEmpty).join(' • '),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _dispararRascunho(Map<String, dynamic> c) async {
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (gabinete == null || gabinete.token == null) return;

    // Busca envios salvos para montar a lista de telefones
    final telefones = await ref
        .read(transmissaoRepositoryProvider)
        .getEnviosTelefones(c['id']);

    if (telefones.isEmpty) return;

    final apiType = 'text';
    final result = await ref.read(uazapiServiceProvider).criarCampanhaSimples(
          instanceToken: gabinete.token!,
          telefones: telefones,
          tipo: apiType,
          folder: c['titulo'] ?? 'Campanha',
          delayMin: 0,
          delayMax: 0,
          scheduledFor: DateTime.now().millisecondsSinceEpoch,
          text: c['mensagem'] ?? '',
          info: 'gabitech',
        );

    if (result.isSuccess) {
      await ref
          .read(transmissaoRepositoryProvider)
          .updateStatus(id: c['id'], status: 'Enviado');
      ref.invalidate(transmissoesProvider);
    }
  }

  bool _matchesTransmissao(Cidadao cid, Map<String, dynamic> t) {
    final bairros = (t['bairros'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];
    final perfis = (t['perfil'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];
    final genero = (t['genero'] ?? '').toString().toLowerCase();

    if (bairros.isNotEmpty) {
      final b = (cid.bairro ?? '').toLowerCase();
      if (b.isEmpty || !bairros.contains(b)) return false;
    }
    if (perfis.isNotEmpty) {
      final p = (cid.perfil ?? '').toLowerCase();
      if (p.isEmpty || !perfis.contains(p)) return false;
    }
    if (genero.isNotEmpty && genero != 'todos') {
      final g = (cid.genero ?? '').toLowerCase();
      if (g.isEmpty || g != genero) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final transmissoesAsync = ref.watch(transmissoesProvider);
    final metrics = ref.watch(transmissoesMetricsProvider);
    final statusOptions = const [
      'Todas',
      'Agendada',
      'Enviando',
      'Enviado',
      'Rascunho',
      'Falha'
    ];

    final list = transmissoesAsync.value ?? [];
    final bairros = <String>{'Todos'};
    final perfis = <String>{'Todos'};
    for (final c in list) {
      final b = c['bairros'];
      if (b is List) {
        for (final item in b) {
          if (item != null && item.toString().trim().isNotEmpty) {
            bairros.add(item.toString());
          }
        }
      }
      final p = c['perfil'];
      if (p is List) {
        for (final item in p) {
          if (item != null && item.toString().trim().isNotEmpty) {
            perfis.add(item.toString());
          }
        }
      }
    }

    DateTime? parseDataCampanha(Map<String, dynamic> c) {
      final ag = c['data_agendamento'];
      if (ag is int) {
        return DateTime.fromMillisecondsSinceEpoch(ag * 1000);
      }
      final data = (c['data'] ?? '').toString();
      if (data.contains('/')) {
        final parts = data.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]) ?? 1;
          final m = int.tryParse(parts[1]) ?? 1;
          final y = int.tryParse(parts[2]) ?? 2000;
          return DateTime(y, m, d);
        }
      }
      return null;
    }

    final filtered = list.where((c) {
      final statusOk =
          _statusFilter == 'Todas' || (c['status']?.toString() == _statusFilter);
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return statusOk;
      final titulo = (c['titulo'] ?? '').toString().toLowerCase();
      final mensagem = (c['mensagem'] ?? '').toString().toLowerCase();
      final matchQuery = titulo.contains(query) || mensagem.contains(query);

      final bairroOk = _bairroFilter == 'Todos'
          ? true
          : ((c['bairros'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .contains(_bairroFilter) ??
              false);
      final perfilOk = _perfilFilter == 'Todos'
          ? true
          : ((c['perfil'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .contains(_perfilFilter) ??
              false);

      final dateOk = _dateRange == null
          ? true
          : (() {
              final dt = parseDataCampanha(c);
              if (dt == null) return true;
              return !(dt.isBefore(_dateRange!.start) ||
                  dt.isAfter(_dateRange!.end));
            })();

      return statusOk && matchQuery && bairroOk && perfilOk && dateOk;
    }).toList();

    return MainLayout(
      title: 'Transmissões',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Transmissões',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('Mensagens agendadas para cidadãos',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCriarCampanha,
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Nova Transmissão'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Metric cards
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total',
                    value: '${metrics.total}',
                    icon: LucideIcons.navigation,
                    color: const Color(0xFFE8EEF9),
                    accent: const Color(0xFF355CBE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Agendadas',
                    value: '${metrics.agendadas}',
                    icon: LucideIcons.clock,
                    color: const Color(0xFFFCEEEA),
                    accent: const Color(0xFFC5502B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Enviando',
                    value: '${metrics.enviando}',
                    icon: LucideIcons.messageSquare,
                    color: const Color(0xFFE7F4FE),
                    accent: const Color(0xFF1D7FC9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Enviadas',
                    value: '${metrics.finalizadas}',
                    icon: LucideIcons.checkCircle,
                    color: const Color(0xFFE8F8EE),
                    accent: const Color(0xFF1B7F3F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Alcançados',
                    value: '${metrics.impactados}',
                    icon: LucideIcons.users,
                    color: const Color(0xFFFFF5E6),
                    accent: const Color(0xFFB66510),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Filters + quick actions
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(LucideIcons.search, size: 18),
                          hintText: 'Buscar por título ou mensagem',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        underline: const SizedBox.shrink(),
                        items: statusOptions
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _statusFilter = value ?? 'Todas'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<String>(
                        value: _bairroFilter,
                        underline: const SizedBox.shrink(),
                        items: bairros
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (value) => setState(
                          () => _bairroFilter = value ?? 'Todos',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<String>(
                        value: _perfilFilter,
                        underline: const SizedBox.shrink(),
                        items: perfis
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (value) => setState(
                          () => _perfilFilter = value ?? 'Todos',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 1),
                          initialDateRange: _dateRange,
                        );
                        if (range != null) {
                          setState(() => _dateRange = range);
                        }
                      },
                      icon: const Icon(LucideIcons.calendar, size: 16),
                      label: Text(
                        _dateRange == null
                            ? 'Período'
                            : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _statusFilter = 'Todas';
                          _bairroFilter = 'Todos';
                          _perfilFilter = 'Todos';
                          _dateRange = null;
                        });
                      },
                      icon: const Icon(LucideIcons.rotateCcw, size: 16),
                      label: const Text('Limpar filtros'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              LucideIcons.list,
                              color: Colors.blueGrey.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Lista de Transmissões',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              ref.invalidate(campanhasApiProvider);
                            },
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: const Text('Atualizar Status'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: const [
                          _LegendChip(label: 'Agendada', color: Colors.orange),
                          _LegendChip(label: 'Enviando', color: Colors.blue),
                          _LegendChip(label: 'Enviado', color: Colors.green),
                          _LegendChip(label: 'Rascunho', color: Colors.grey),
                          _LegendChip(label: 'Falha', color: Colors.red),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: transmissoesAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (err, _) => Center(
                            child: Text(
                              'Erro ao carregar transmissões: $err',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                          data: (_) => filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        LucideIcons.inbox,
                                        size: 64,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Nenhuma transmissão cadastrada',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Clique em "Nova Transmissão" para começar',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx, i) {
                                    final c = filtered[i];
                                  final status = c['status'] ?? 'Rascunho';
                                  final statusColor = status == 'Enviado'
                                      ? Colors.green
                                      : status == 'Enviando'
                                          ? Colors.blue
                                          : status == 'Agendada'
                                              ? Colors.orange
                                              : status == 'Falha'
                                                  ? Colors.red
                                              : Colors.grey;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Status indicator
                                            Container(
                                              width: 4,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Content
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          c['titulo'] ?? '',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: statusColor
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              status ==
                                                                      'Enviado'
                                                                  ? LucideIcons
                                                                      .checkCircle
                                                                  : status ==
                                                                          'Enviando'
                                                                      ? LucideIcons
                                                                          .loader
                                                                      : status ==
                                                                              'Agendada'
                                                                          ? LucideIcons
                                                                              .clock
                                                                          : LucideIcons
                                                                              .fileText,
                                                              size: 14,
                                                              color: statusColor
                                                                  .shade700,
                                                            ),
                                                            const SizedBox(
                                                                width: 6),
                                                            Text(
                                                              status,
                                                              style: TextStyle(
                                                                color:
                                                                    statusColor
                                                                        .shade700,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    c['mensagem'] ?? '',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 16,
                                                    runSpacing: 8,
                                                    children: [
                                                      _InfoChip(
                                                        icon: LucideIcons
                                                            .calendar,
                                                        label: c['data'] ?? '',
                                                      ),
                                                      _InfoChip(
                                                        icon: LucideIcons.clock,
                                                        label: c['hora'] ?? '',
                                                      ),
                                                      _InfoChip(
                                                        icon: LucideIcons.users,
                                                        label: c['qtd'] == null
                                                            ? 'Alvos: -'
                                                            : '${c['qtd']} cidadãos',
                                                      ),
                                                      // Status de envios (da API)
                                                      Builder(
                                                        builder: (context) {
                                                          final logSuccess = c['log_success'] as int? ?? 0;
                                                          final logFailed = c['log_failed'] as int? ?? 0;
                                                          if (logSuccess == 0 && logFailed == 0) {
                                                            return const SizedBox.shrink();
                                                          }
                                                          return _EnvioStatsChip(
                                                            enviados: logSuccess,
                                                            falhas: logFailed,
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Actions
                                          Column(
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      if (status == 'Rascunho')
                                                        IconButton(
                                                          icon: Icon(
                                                            LucideIcons.send,
                                                            size: 18,
                                                            color: Colors
                                                                .grey.shade700,
                                                          ),
                                                          onPressed: () async {
                                                            await _dispararRascunho(c);
                                                          },
                                                          tooltip: 'Disparar',
                                                        ),
                                                      if (status == 'Rascunho')
                                                        Container(
                                                          width: 1,
                                                          height: 20,
                                                          color: Colors
                                                              .grey.shade300,
                                                        ),
                                                      IconButton(
                                                        icon: Icon(
                                                          LucideIcons.eye,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade700,
                                                        ),
                                                        onPressed: () =>
                                                            _openDetalhes(c),
                                                        tooltip: 'Visualizar',
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 20,
                                                        color: Colors
                                                            .grey.shade300,
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          LucideIcons.edit2,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade700,
                                                        ),
                                                        onPressed: () {},
                                                        tooltip: 'Editar',
                                                      ),
                                                      Container(
                                                        width: 1,
                                                        height: 20,
                                                        color: Colors
                                                            .grey.shade300,
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          LucideIcons.copy,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade700,
                                                        ),
                                                        onPressed: () {},
                                                        tooltip: 'Duplicar',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small metric card used in header
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color accent;

  const _MetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.accent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2A37),
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

// Info chip for displaying campaign details
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    Key? key,
    required this.icon,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip para mostrar estatísticas de envio (OK/Falha)
class _EnvioStatsChip extends StatelessWidget {
  final int enviados;
  final int falhas;

  const _EnvioStatsChip({
    Key? key,
    required this.enviados,
    required this.falhas,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.send,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          // OK
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 12, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '$enviados',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Falha
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.x, size: 12, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  '$falhas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
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

class _LegendChip extends StatelessWidget {
  final String label;
  final MaterialColor color;

  const _LegendChip({
    Key? key,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog de criação/edição de campanha — componente completo com filtros e seleção manual
class CriarCampanhaDialog extends ConsumerStatefulWidget {
  const CriarCampanhaDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<CriarCampanhaDialog> createState() =>
      _CriarCampanhaDialogState();
}

class _CriarCampanhaDialogState extends ConsumerState<CriarCampanhaDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _mensagemController = TextEditingController();
  DateTime? _dataAgendamento;
  TimeOfDay? _horaAgendamento;
  bool _agendar = false;
  bool _salvarComoRascunho = false;

  // filtros
  final List<String> _bairrosSelecionados = [];
  final List<String> _perfisSelecionados = [];
  String _generoSelecionado = 'Todos';
  bool _selecionarManual = false;

  // seleção manual (mock)
  final List<Map<String, String>> _cidsSelecionados = [];
  final Set<int> _cidadaosExcluidos = {};

  // Tipo de envio: text/file/video/document
  String _tipoEnvio = 'texto';
  final TextEditingController _arquivoController = TextEditingController();
  final TextEditingController _docNameController = TextEditingController();

  @override
  void dispose() {
    _tituloController.dispose();
    _mensagemController.dispose();
    _arquivoController.dispose();
    _docNameController.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d != null) setState(() => _dataAgendamento = d);
  }

  Future<void> _pickHora() async {
    final h =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (h != null) setState(() => _horaAgendamento = h);
  }

  List<Cidadao> _aplicarFiltrosPublico(List<Cidadao> cidadaos) {
    return cidadaos.where((c) {
      if (_bairrosSelecionados.isNotEmpty) {
        final bairro = c.bairro?.trim() ?? '';
        if (bairro.isEmpty ||
            !_bairrosSelecionados
                .map((b) => b.toLowerCase())
                .contains(bairro.toLowerCase())) {
          return false;
        }
      }
      if (_perfisSelecionados.isNotEmpty) {
        final perfil = c.perfil?.trim() ?? '';
        if (perfil.isEmpty ||
            !_perfisSelecionados
                .map((p) => p.toLowerCase())
                .contains(perfil.toLowerCase())) {
          return false;
        }
      }
      if (_generoSelecionado != 'Todos') {
        final genero = c.genero?.trim() ?? '';
        if (genero.isEmpty ||
            genero.toLowerCase() != _generoSelecionado.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _confirmarSalvar() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _tituloController.text.trim();
    final mensagem = _mensagemController.text.trim();
    final now = DateTime.now();

    // Buscar gabinete atual para obter token
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (!mounted) return;
    if (gabinete == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gabinete não encontrado')));
      return;
    }

    final instanceToken = gabinete.token;
    if (instanceToken == null || instanceToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token do gabinete não configurado')));
      return;
    }

    if (!_salvarComoRascunho &&
        _agendar &&
        (_dataAgendamento == null || _horaAgendamento == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defina data e hora do agendamento')));
      return;
    }

    // Montar lista de telefones + alvos
    List<String> telefones = [];
    List<Cidadao> alvos = [];
    if (_selecionarManual && _cidsSelecionados.isNotEmpty) {
      telefones = _cidsSelecionados
          .map((c) => c['telefone'] ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      // Tenta vincular cidadão pelo telefone (se existir)
      try {
        final cidRepo = ref.read(cidadaoRepositoryProvider);
        final cidadaos = await cidRepo.getByGabinete(gabinete.id, limit: 2000);
        final telSet = telefones.toSet();
        alvos = cidadaos
            .where((c) => telSet.contains(c.telefone ?? ''))
            .toList();
      } catch (_) {
        // se falhar, segue sem vincular cidadãos
      }
    } else {
      // Buscar cidadaos do gabinete aplicando filtros mínimos (pode ser expandido)
      try {
        final cidRepo = ref.read(cidadaoRepositoryProvider);
        final gabId = gabinete.id;
        final cidadaos = await cidRepo.getByGabinete(gabId, limit: 1000);
        final filtrados = _aplicarFiltrosPublico(cidadaos);
        alvos = filtrados;
        telefones = filtrados
            .map((c) => c.telefone ?? '')
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao buscar cidadãos: $e')));
        return;
      }
    }

    if (_cidadaosExcluidos.isNotEmpty) {
      final excluidosTelefones = alvos
          .where((c) => _cidadaosExcluidos.contains(c.id))
          .map((c) => c.telefone ?? '')
          .where((t) => t.isNotEmpty)
          .toSet();
      alvos = alvos.where((c) => !_cidadaosExcluidos.contains(c.id)).toList();
      if (excluidosTelefones.isNotEmpty) {
        telefones = telefones
            .where((t) => !excluidosTelefones.contains(t))
            .toList();
      }
    }

    if (!mounted) return;

    if (telefones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum telefone encontrado para envio')));
      return;
    }

    final dataAgendamento = _agendar
        ? DateTime(
            _dataAgendamento!.year,
            _dataAgendamento!.month,
            _dataAgendamento!.day,
            _horaAgendamento!.hour,
            _horaAgendamento!.minute,
          )
        : null;

    final dataStr = _agendar
        ? '${_dataAgendamento!.day}/${_dataAgendamento!.month}/${_dataAgendamento!.year}'
        : '${now.day}/${now.month}/${now.year}';
    final horaStr = _agendar
        ? _horaAgendamento!.format(context)
        : '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final transmissaoRepo = ref.read(transmissaoRepositoryProvider);
    // Usar o nome como id_campanha para fazer match com o folder da API
    final idCampanha = nome;
    final statusInicial = _salvarComoRascunho
        ? 'Rascunho'
        : (_agendar
            ? 'Agendada'
            : (_tipoEnvio == 'texto' ? 'Enviando' : 'Rascunho'));

    // LOG: Antes de criar transmissão
    debugPrint('[CAMPANHA] Criando transmissão: gabinete=${gabinete.id}, idCampanha=$idCampanha, titulo=$nome, status=$statusInicial, telefones=${telefones.length}');

    Map<String, dynamic> registro;
    try {
      registro = await transmissaoRepo.createTransmissao(
        gabineteId: gabinete.id,
        idCampanha: idCampanha,
        titulo: nome,
        mensagem: mensagem,
        status: statusInicial,
        data: dataStr,
        hora: horaStr,
        qtd: telefones.length,
        dataAgendamento:
            dataAgendamento == null ? null : (dataAgendamento.millisecondsSinceEpoch ~/ 1000),
        genero: _generoSelecionado == 'Todos' ? null : _generoSelecionado,
        perfil: _perfisSelecionados.isEmpty ? null : _perfisSelecionados,
        bairros: _bairrosSelecionados.isEmpty ? null : _bairrosSelecionados,
        categorias: null,
      );
      debugPrint('[CAMPANHA] Transmissão criada com sucesso: $registro');
    } catch (e, st) {
      debugPrint('[CAMPANHA] ERRO ao criar transmissão: $e');
      debugPrint('[CAMPANHA] StackTrace: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transmissão: $e')));
      return;
    }

    final transmissaoId = registro['id'] as int?;
    debugPrint('[CAMPANHA] transmissaoId extraído: $transmissaoId');

    if (transmissaoId != null) {
      final envios = <Map<String, dynamic>>[];
      final mapTelefoneParaId = {
        for (final c in alvos)
          if (c.telefone != null && c.telefone!.isNotEmpty) c.telefone!: c.id
      };
      for (final tel in telefones) {
        envios.add({
          'cidadao_id': mapTelefoneParaId[tel],
          'telefone': tel,
          'status': 'pendente',
        });
      }

      debugPrint('[CAMPANHA] Criando ${envios.length} envios para transmissaoId=$transmissaoId');
      try {
        await transmissaoRepo.createEnviosBulk(
          transmissaoId: transmissaoId,
          envios: envios,
        );
        debugPrint('[CAMPANHA] Envios criados com sucesso');
      } catch (e, st) {
        debugPrint('[CAMPANHA] ERRO ao criar envios: $e');
        debugPrint('[CAMPANHA] StackTrace: $st');
      }
    } else {
      debugPrint('[CAMPANHA] AVISO: transmissaoId é null, não foi possível criar envios');
    }

    final uaz = ref.read(uazapiServiceProvider);
    final scheduledFor = dataAgendamento?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    String apiType = 'text';
    if (_tipoEnvio == 'arquivo') apiType = 'image';
    if (_tipoEnvio == 'video') apiType = 'video';
    if (_tipoEnvio == 'documento') apiType = 'document';

    String? fileUrl;
    if (_tipoEnvio != 'texto') {
      fileUrl = _arquivoController.text.trim();
      if (fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Informe a URL do arquivo para envio')));
        return;
      }
    }

    if (_salvarComoRascunho) {
      debugPrint('[CAMPANHA] Salvando como rascunho, não vai chamar API');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rascunho salvo com sucesso')));
      ref.invalidate(transmissoesProvider);
      Navigator.of(context).pop(true);
      return;
    }

    debugPrint('[CAMPANHA] Chamando API uazapi.criarCampanhaSimples: tipo=$apiType, telefones=${telefones.length}, folder=$nome');
    final result = await uaz.criarCampanhaSimples(
      instanceToken: instanceToken,
      telefones: telefones,
      tipo: apiType,
      folder: nome,
      delayMin: 0,
      delayMax: 0,
      scheduledFor: scheduledFor,
      text: mensagem,
      file: fileUrl,
      info: 'gabitech',
    );

    debugPrint('[CAMPANHA] Resultado da API: isSuccess=${result.isSuccess}, error=${result.error}, data=${result.data}');

    if (!mounted) return;
    if (result.isSuccess) {
      final id = registro['id'] as int?;
      debugPrint('[CAMPANHA] API sucesso! Atualizando status da transmissão id=$id para ${_agendar ? 'Agendada' : 'Enviando'}');
      if (id != null) {
        try {
          // Se não é agendamento, colocar como "Enviando" e aguardar verificação
          await transmissaoRepo.updateStatus(
            id: id,
            status: _agendar ? 'Agendada' : 'Enviando',
          );
          debugPrint('[CAMPANHA] Status atualizado com sucesso');

          // Agendar verificação automática após 60 segundos
          // O 'nome' é usado como folder/id na API
          debugPrint('[CAMPANHA] Agendando verificação automática em 60 segundos...');
          agendarVerificacaoCampanha(
            ref: ref,
            transmissaoId: id,
            idCampanha: nome, // folder na API = nome da campanha
            instanceToken: instanceToken,
            delaySeconds: 60,
          );
        } catch (e, st) {
          debugPrint('[CAMPANHA] ERRO ao atualizar status: $e');
          debugPrint('[CAMPANHA] StackTrace: $st');
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campanha "$nome" enviada com sucesso')));
      ref.invalidate(transmissoesProvider);
      ref.invalidate(campanhasApiProvider);
      Navigator.of(context).pop(true);
      return;
    }

    final id = registro['id'] as int?;
    debugPrint('[CAMPANHA] API falhou! Atualizando status da transmissão id=$id para Falha');
    if (id != null) {
      try {
        await transmissaoRepo.updateStatus(id: id, status: 'Falha');
        debugPrint('[CAMPANHA] Status atualizado para Falha');
      } catch (e, st) {
        debugPrint('[CAMPANHA] ERRO ao atualizar status para Falha: $e');
        debugPrint('[CAMPANHA] StackTrace: $st');
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar campanha: ${result.error}')));
    return;
  }

  @override
  Widget build(BuildContext context) {
    final cidadaosAsync = ref.watch(cidadaosMapRawProvider);
    final cidadaos = cidadaosAsync.valueOrNull ?? [];
    final bairros = cidadaos
        .map((c) => c.bairro?.trim() ?? '')
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final perfis = cidadaos
        .map((c) => c.perfil?.trim() ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final generos = <String>{
      'Todos',
      ...cidadaos
          .map((c) => c.genero?.trim() ?? '')
          .where((g) => g.isNotEmpty),
    }.toList()
      ..sort();
    final targets = _aplicarFiltrosPublico(cidadaos)
        .where((c) => !_cidadaosExcluidos.contains(c.id))
        .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Criar Campanha',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(false))
              ]),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                          labelText: 'Título',
                          hintText: 'ex: Vamos construir uma lombada'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _mensagemController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                          labelText: 'Mensagem',
                          hintText: 'Escreva a mensagem a ser enviada'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Obrigatório' : null),
                  const SizedBox(height: 12),

                  // agendamento
                  Row(children: [
                    Expanded(
                        child: InkWell(
                            onTap: _pickData,
                            child: InputDecorator(
                                decoration:
                                    const InputDecoration(labelText: 'Data'),
                                child: Text(_dataAgendamento == null
                                    ? 'dd/mm/aaaa'
                                    : '${_dataAgendamento!.day}/${_dataAgendamento!.month}/${_dataAgendamento!.year}')))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: InkWell(
                            onTap: _pickHora,
                            child: InputDecorator(
                                decoration:
                                    const InputDecoration(labelText: 'Hora'),
                                child: Text(_horaAgendamento == null
                                    ? 'HH:MM'
                                    : _horaAgendamento!.format(context))))),
                  ]),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                      value: _agendar,
                      onChanged: (v) => setState(() => _agendar = v ?? false),
                      title: const Text('Agendar envio')),
                  const SizedBox(height: 8),

                  // filtros
                  ExpansionTile(
                      title: const Text('Filtros de Público Alvo'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Bairros',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: bairros.isEmpty
                              ? [const Text('Nenhum bairro cadastrado')]
                              : bairros.map((b) {
                                  final selected =
                                      _bairrosSelecionados.contains(b);
                                  return FilterChip(
                                    label: Text(b),
                                    selected: selected,
                                    onSelected: (v) {
                                      setState(() {
                                        if (v) {
                                          _bairrosSelecionados.add(b);
                                        } else {
                                          _bairrosSelecionados.remove(b);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Perfis',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: perfis.isEmpty
                              ? [const Text('Nenhum perfil cadastrado')]
                              : perfis.map((p) {
                                  final selected =
                                      _perfisSelecionados.contains(p);
                                  return FilterChip(
                                    label: Text(p),
                                    selected: selected,
                                    onSelected: (v) {
                                      setState(() {
                                        if (v) {
                                          _perfisSelecionados.add(p);
                                        } else {
                                          _perfisSelecionados.remove(p);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Gênero',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _generoSelecionado,
                          items: generos
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(
                            () => _generoSelecionado = value ?? 'Todos',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Gênero',
                          ),
                        ),
                      ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cidadãos selecionados',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _selecionarManual
                                  ? '${_cidsSelecionados.length}'
                                  : '${targets.length}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 160,
                          child: _selecionarManual
                              ? (_cidsSelecionados.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Nenhum cidadão selecionado',
                                        style: TextStyle(
                                            color: Colors.grey.shade600),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _cidsSelecionados.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                      itemBuilder: (context, i) {
                                        final c = _cidsSelecionados[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(c['nome'] ?? ''),
                                          subtitle: Text(c['telefone'] ?? ''),
                                          trailing: IconButton(
                                            icon: const Icon(LucideIcons.x),
                                            onPressed: () {
                                              setState(() {
                                                _cidsSelecionados.removeAt(i);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ))
                              : (targets.isEmpty
                                  ? Center(
                                      child: Text(
                                        'Nenhum cidadão encontrado',
                                        style: TextStyle(
                                            color: Colors.grey.shade600),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: targets.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                      itemBuilder: (context, i) {
                                        final c = targets[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(c.nome ?? 'Sem nome'),
                                          subtitle: Text(c.telefone ?? ''),
                                          trailing: IconButton(
                                            icon: const Icon(LucideIcons.x),
                                            onPressed: () {
                                              setState(() {
                                                _cidadaosExcluidos.add(c.id);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // seleção manual
                  CheckboxListTile(
                      value: _selecionarManual,
                      onChanged: (v) =>
                          setState(() => _selecionarManual = v ?? false),
                      title: const Text('Selecionar cidadãos manualmente')),
                  if (_selecionarManual)
                    Column(children: [
                      TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Buscar por nome, telefone ou CPF'),
                          onChanged: (v) {}),
                      const SizedBox(height: 8),
                      SizedBox(
                          height: 120,
                          child: ListView(children: [
                            CheckboxListTile(
                                value: _cidsSelecionados
                                    .any((c) => c['cpf'] == '123'),
                                onChanged: (v) => setState(() {
                                      if (v == true)
                                        _cidsSelecionados.add({
                                          'nome': 'Maria Silva',
                                          'telefone': '99999-0001',
                                          'cpf': '123'
                                        });
                                      else
                                        _cidsSelecionados.removeWhere(
                                            (c) => c['cpf'] == '123');
                                    }),
                                title: const Text('Maria Silva'),
                                subtitle: const Text('99999-0001')),
                            CheckboxListTile(
                                value: _cidsSelecionados
                                    .any((c) => c['cpf'] == '456'),
                                onChanged: (v) => setState(() {
                                      if (v == true)
                                        _cidsSelecionados.add({
                                          'nome': 'João Souza',
                                          'telefone': '99999-0002',
                                          'cpf': '456'
                                        });
                                      else
                                        _cidsSelecionados.removeWhere(
                                            (c) => c['cpf'] == '456');
                                    }),
                                title: const Text('João Souza'),
                                subtitle: const Text('99999-0002')),
                          ]))
                    ]),

                  const SizedBox(height: 12),

                  // Tipo de envio (define qual API será usada)
                  Row(children: [
                    const Text('Tipo de envio: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                        label: const Text('Texto'),
                        selected: _tipoEnvio == 'texto',
                        onSelected: (s) =>
                            setState(() => _tipoEnvio = 'texto')),
                    const SizedBox(width: 6),
                    ChoiceChip(
                        label: const Text('Arquivo'),
                        selected: _tipoEnvio == 'arquivo',
                        onSelected: (s) =>
                            setState(() => _tipoEnvio = 'arquivo')),
                    const SizedBox(width: 6),
                    ChoiceChip(
                        label: const Text('Vídeo'),
                        selected: _tipoEnvio == 'video',
                        onSelected: (s) =>
                            setState(() => _tipoEnvio = 'video')),
                    const SizedBox(width: 6),
                    ChoiceChip(
                        label: const Text('Documento'),
                        selected: _tipoEnvio == 'documento',
                        onSelected: (s) =>
                            setState(() => _tipoEnvio = 'documento')),
                  ]),

                  const SizedBox(height: 12),
                  if (_tipoEnvio != 'texto')
                    TextFormField(
                      controller: _arquivoController,
                      decoration: const InputDecoration(
                        labelText: 'URL do arquivo',
                        hintText: 'https://.../arquivo',
                      ),
                      validator: (v) {
                        if (_tipoEnvio != 'texto' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Obrigatório para este tipo';
                        }
                        return null;
                      },
                    ),
                  if (_tipoEnvio == 'documento') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _docNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do documento (opcional)',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: () {
                        setState(() => _salvarComoRascunho = true);
                        _confirmarSalvar();
                      },
                      child: const Text('Salvar rascunho')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: () {
                        setState(() => _salvarComoRascunho = false);
                        _confirmarSalvar();
                      },
                      child: const Text('Salvar campanha'))
                ])
                ]),
              )
            ]),
          ),
        ),
      ),
    );
  }
}
