import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../data/models/cidadao.dart';
import '../../data/models/solicitacao.dart';
import '../../data/models/tarefa.dart';
import '../../data/models/nota_tarefa.dart';
import '../../providers/cidadao_providers.dart';
import '../../providers/tarefa_providers.dart';
import '../../providers/core_providers.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Dialog to show solicitacao details with tabs
class SolicitacaoDetailsDialog extends ConsumerStatefulWidget {
  final Solicitacao solicitacao;

  const SolicitacaoDetailsDialog({
    super.key,
    required this.solicitacao,
  });

  @override
  ConsumerState<SolicitacaoDetailsDialog> createState() =>
      _SolicitacaoDetailsDialogState();
}

class _SolicitacaoDetailsDialogState
    extends ConsumerState<SolicitacaoDetailsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sol = widget.solicitacao;

    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: maxHeight,
        ),
        child: Material(
          color: AppColors.surface,
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x),
                        tooltip: 'Fechar',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sol.titulo ?? 'Solicitação #${sol.id}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      _buildStatusChip(sol.statusEnum),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Detalhes'),
                      Tab(text: 'Atividades'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDetailsTab(context),
                      _buildAtividadesTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab(
      BuildContext context) {
    final sol = widget.solicitacao;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info grid
          _buildInfoGrid(context, sol),

          const Divider(height: 32),

          // Cidadão info
          _buildCidadaoSection(context, sol),

          // Descrição
          if (sol.descricao != null && sol.descricao!.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Descrição',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              sol.descricao!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],

          // Resumo
          if (sol.resumo != null && sol.resumo!.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Resumo da Conversa',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Text(
                sol.resumo!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCidadaoSection(BuildContext context, Solicitacao sol) {
    // Se já tem cidadao no objeto, usa direto
    if (sol.cidadao != null) {
      return _buildCidadaoCard(context, sol.cidadao!);
    }
    
    // Senão, busca pelo ID via provider
    if (sol.cidadaoId == null) {
      return const SizedBox.shrink();
    }

    final cidadaoAsync = ref.watch(cidadaoProvider(sol.cidadaoId!));

    return cidadaoAsync.when(
      data: (cidadao) {
        if (cidadao == null) return const SizedBox.shrink();
        return _buildCidadaoCard(context, cidadao);
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCidadaoCard(BuildContext context, Cidadao cidadao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cidadão',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CachedAvatar(
                    radius: 24,
                    imageUrl: cidadao.foto,
                    name: cidadao.nome,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cidadao.nome ?? 'Cidadão',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (cidadao.perfil != null)
                          Text(
                            cidadao.perfil!,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (cidadao.telefone != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.phone,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatTelefone(cidadao.telefone!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Copiar número
                            IconButton(
                              icon: Icon(
                                LucideIcons.copy,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: cidadao.telefone!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Número copiado!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              tooltip: 'Copiar número',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(width: 8),
                            // WhatsApp
                            IconButton(
                              icon: const Icon(
                                LucideIcons.messageCircle,
                                size: 16,
                                color: Color(0xFF25D366),
                              ),
                              onPressed: () => _openWhatsApp(cidadao.telefone!),
                              tooltip: 'Abrir WhatsApp',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(width: 8),
                            // Ligar
                            IconButton(
                              icon: Icon(
                                LucideIcons.phoneCall,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _makePhoneCall(cidadao.telefone!),
                              tooltip: 'Ligar',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAtividadesTab(BuildContext context) {
    final sol = widget.solicitacao;

    final tarefasAsync = ref.watch(atividadesBySolicitacaoProvider(sol.id));

    return Column(
      children: [
        // Header with add button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(
                LucideIcons.listChecks,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Atividades desta Solicitação',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddAtividadeDialog(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Nova'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Lista de atividades
        Expanded(
          child: tarefasAsync.when(
            data: (tarefas) {
              if (tarefas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma atividade cadastrada',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showAddAtividadeDialog(context),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Adicionar atividade'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: tarefas.length,
                itemBuilder: (context, index) {
                  final tarefa = tarefas[index];
                  return _buildTarefaCard(context, tarefa);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Erro ao carregar atividades',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTarefaCard(BuildContext context, Tarefa tarefa) {
    final isConcluida = tarefa.status?.toLowerCase() == 'concluida';

    return _TarefaCardExpandable(
      tarefa: tarefa,
      solicitacao: widget.solicitacao,
      isConcluida: isConcluida,
    );
  }

  void _showAddAtividadeDialog(BuildContext context) {
    final tituloController = TextEditingController();
    final descricaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Atividade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tituloController,
              decoration: const InputDecoration(
                labelText: 'Título *',
                hintText: 'Digite o título da atividade',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Descrição opcional',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tituloController.text.isEmpty) return;

              await ref.read(tarefaNotifierProvider.notifier).create(
                    solicitacaoId: widget.solicitacao.id,
                    titulo: tituloController.text,
                    descricao: descricaoController.text.isNotEmpty
                        ? descricaoController.text
                        : null,
                  );

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, Solicitacao sol) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _buildInfoItem(
          context,
          icon: LucideIcons.tag,
          label: 'Categoria',
          value: sol.categoria ?? 'Não definida',
        ),
        _buildInfoItem(
          context,
          icon: LucideIcons.gauge,
          label: 'Prioridade',
          value: sol.prioridade ?? 'Média',
          valueColor: _getPriorityColor(sol.prioridade),
        ),
        _buildInfoItem(
          context,
          icon: LucideIcons.calendar,
          label: 'Prazo',
          value: sol.prazo ?? 'Não definido',
        ),
        _buildInfoItem(
          context,
          icon: LucideIcons.user,
          label: 'Assessor',
          value: sol.nomeAcessor ?? 'Não atribuído',
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(SolicitacaoStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'alta':
        return AppColors.error;
      case 'média':
      case 'media':
        return AppColors.warning;
      case 'baixa':
        return AppColors.success;
      default:
        return AppColors.textPrimary;
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Remove caracteres não numéricos
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final whatsappUrl = Uri.parse('https://wa.me/55$cleanPhone');
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final phoneUrl = Uri.parse('tel:$cleanPhone');
    
    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    }
  }

  /// Formata o telefone removendo @s.whatsapp.net e formatando visualmente
  String _formatTelefone(String telefone) {
    // Remove @s.whatsapp.net ou similar
    String numero = telefone.replaceAll(RegExp(r'@.*'), '');
    
    // Remove caracteres não numéricos
    numero = numero.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Se começar com 55 (Brasil), formata
    if (numero.startsWith('55') && numero.length >= 12) {
      final ddd = numero.substring(2, 4);
      final parte1 = numero.substring(4, numero.length - 4);
      final parte2 = numero.substring(numero.length - 4);
      return '($ddd) $parte1-$parte2';
    }
    
    // Formato genérico para outros números
    if (numero.length >= 10) {
      final ddd = numero.substring(0, 2);
      final parte1 = numero.substring(2, numero.length - 4);
      final parte2 = numero.substring(numero.length - 4);
      return '($ddd) $parte1-$parte2';
    }
    
    return numero.isNotEmpty ? numero : telefone;
  }
}

// ============================================
// TAREFA CARD EXPANDABLE WITH NOTES
// ============================================

class _TarefaCardExpandable extends ConsumerStatefulWidget {
  final Tarefa tarefa;
  final Solicitacao solicitacao;
  final bool isConcluida;

  const _TarefaCardExpandable({
    required this.tarefa,
    required this.solicitacao,
    required this.isConcluida,
  });

  @override
  ConsumerState<_TarefaCardExpandable> createState() => _TarefaCardExpandableState();
}

class _TarefaCardExpandableState extends ConsumerState<_TarefaCardExpandable> {
  bool _isExpanded = false;
  final _notaController = TextEditingController();

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notasAsync = ref.watch(notasBySolicitacaoProvider(widget.solicitacao.id));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isConcluida
            ? AppColors.success.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isConcluida 
              ? AppColors.success.withValues(alpha: 0.3) 
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Main tarefa row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox
                InkWell(
                  onTap: () {
                    final newStatus = widget.isConcluida ? 'pendente' : 'concluida';
                    ref.read(tarefaNotifierProvider.notifier).updateStatus(
                          widget.tarefa.id,
                          widget.solicitacao.id,
                          newStatus,
                        );
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.isConcluida ? AppColors.success : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.isConcluida ? AppColors.success : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: widget.isConcluida
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.tarefa.titulo ?? 'Sem título',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  decoration: widget.isConcluida ? TextDecoration.lineThrough : null,
                                  color: widget.isConcluida
                                      ? AppColors.textTertiary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // Notes count badge
                            notasAsync.when(
                              data: (notas) => notas.isNotEmpty
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.messageSquare, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${notas.length}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        if (widget.tarefa.descricao != null && widget.tarefa.descricao!.isNotEmpty)
                          Text(
                            widget.tarefa.descricao!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: _isExpanded ? null : 2,
                            overflow: _isExpanded ? null : TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                // Expand button
                IconButton(
                  icon: Icon(
                    _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  tooltip: _isExpanded ? 'Recolher' : 'Expandir notas',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                // Delete button
                IconButton(
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    ref.read(tarefaNotifierProvider.notifier).delete(
                          widget.tarefa.id,
                          widget.solicitacao.id,
                        );
                  },
                  tooltip: 'Excluir',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
          
          // Expanded notes section
          if (_isExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  // Notes header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Icon(LucideIcons.stickyNote, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Notas da Atividade',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Notes list
                  notasAsync.when(
                    data: (notas) {
                      if (notas.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            'Nenhuma nota adicionada',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: notas.length,
                        itemBuilder: (context, index) {
                          final nota = notas[index];
                          return _buildNotaItem(nota);
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Erro ao carregar notas',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ),
                  
                  // Add note input
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _notaController,
                            decoration: InputDecoration(
                              hintText: 'Adicionar nota...',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.primary),
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            minLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addNota,
                          icon: Icon(LucideIcons.send, color: AppColors.primary, size: 20),
                          tooltip: 'Adicionar nota',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotaItem(Nota nota) {
    final dateFormat = DateFormat('dd/MM/yy HH:mm');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.user, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  nota.nomeAutor ?? 'Sistema',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                dateFormat.format(nota.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _deleteNota(nota),
                child: Icon(
                  LucideIcons.x,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nota.descricao ?? '',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNota() async {
    if (_notaController.text.trim().isEmpty) return;
    
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    
    await ref.read(notaNotifierProvider.notifier).create(
      solicitacaoId: widget.solicitacao.id,
      descricao: _notaController.text.trim(),
      nomeAutor: currentUser?.nome ?? 'Usuário',
      autor: currentUser?.uuid,
    );
    
    _notaController.clear();
  }

  Future<void> _deleteNota(Nota nota) async {
    await ref.read(notaNotifierProvider.notifier).delete(
      nota.id,
      widget.solicitacao.id,
    );
  }
}
