import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/models/categoria_tarefa.dart';
import '../../providers/tarefa_providers.dart';
import '../../providers/core_providers.dart';
import '../theme/app_colors.dart';

/// Dialog para gerenciar categorias de solicitações
class CategoriaManagementDialog extends ConsumerStatefulWidget {
  const CategoriaManagementDialog({super.key});

  @override
  ConsumerState<CategoriaManagementDialog> createState() =>
      _CategoriaManagementDialogState();
}

class _CategoriaManagementDialogState
    extends ConsumerState<CategoriaManagementDialog> {
  bool _isLoading = false;

  // Cores pré-definidas para seleção
  static const List<String> _coresPredefinidas = [
    '#3498db', // Azul
    '#e74c3c', // Vermelho
    '#27ae60', // Verde
    '#f39c12', // Laranja
    '#9b59b6', // Roxo
    '#e91e63', // Rosa
    '#00bcd4', // Ciano
    '#795548', // Marrom
    '#607d8b', // Cinza azulado
    '#ff5722', // Laranja escuro
  ];

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasTarefasProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.tags,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gerenciar Categorias',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Categorize suas solicitações por assunto',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: categoriasAsync.when(
                data: (categorias) => _buildCategoriasList(categorias),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'Erro ao carregar: $e',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              ),
            ),

            // Footer - Botão adicionar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _showAddEditDialog(null),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Nova Categoria'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasList(List<CategoriaTarefa> categorias) {
    if (categorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.folderOpen,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma categoria cadastrada',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie categorias para organizar suas solicitações',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: categorias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final categoria = categorias[index];
        return _CategoriaItem(
          categoria: categoria,
          onEdit: () => _showAddEditDialog(categoria),
          onDelete: () => _confirmDelete(categoria),
        );
      },
    );
  }

  Future<void> _showAddEditDialog(CategoriaTarefa? categoria) async {
    final nomeController = TextEditingController(text: categoria?.nome ?? '');
    String selectedCor = categoria?.cor ?? _coresPredefinidas.first;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            categoria == null ? 'Nova Categoria' : 'Editar Categoria',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome
              TextField(
                controller: nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome da categoria',
                  hintText: 'Ex: Infraestrutura, Saúde...',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                autofocus: true,
              ),
              const SizedBox(height: 20),

              // Cor
              Text(
                'Cor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _coresPredefinidas.map((cor) {
                  final isSelected = cor == selectedCor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedCor = cor);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _parseColor(cor),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _parseColor(cor).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomeController.text.trim().isEmpty) return;
                Navigator.pop(ctx, {
                  'nome': nomeController.text.trim(),
                  'cor': selectedCor,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(categoria == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _saveCategoria(categoria?.id, result['nome']!, result['cor']!);
    }
  }

  Future<void> _saveCategoria(int? id, String nome, String cor) async {
    setState(() => _isLoading = true);

    try {
      final gabinete = await ref.read(currentGabineteProvider.future);
      if (gabinete == null) return;

      final categoriaRepo = ref.read(categoriaRepositoryProvider);

      if (id == null) {
        // Criar nova
        await categoriaRepo.create(
          gabineteId: gabinete.id,
          nome: nome,
          cor: cor,
        );
      } else {
        // Atualizar existente
        await categoriaRepo.update(id, nome, cor: cor, gabineteId: gabinete.id);
      }

      // Refresh lista
      ref.invalidate(categoriasTarefasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(id == null
                ? 'Categoria criada com sucesso!'
                : 'Categoria atualizada!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(CategoriaTarefa categoria) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir Categoria',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Tem certeza que deseja excluir a categoria "${categoria.nome}"?\n\n'
          'As solicitações vinculadas a esta categoria ficarão sem categoria.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteCategoria(categoria);
    }
  }

  Future<void> _deleteCategoria(CategoriaTarefa categoria) async {
    setState(() => _isLoading = true);

    try {
      final gabinete = await ref.read(currentGabineteProvider.future);
      if (gabinete == null) return;

      final categoriaRepo = ref.read(categoriaRepositoryProvider);
      await categoriaRepo.delete(categoria.id, gabineteId: gabinete.id);

      // Refresh lista
      ref.invalidate(categoriasTarefasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Categoria excluída!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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

/// Item individual da lista de categorias
class _CategoriaItem extends StatelessWidget {
  final CategoriaTarefa categoria;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoriaItem({
    required this.categoria,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Cor indicator
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _parseColor(categoria.cor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Nome
          Expanded(
            child: Text(
              categoria.nome,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Actions
          IconButton(
            onPressed: onEdit,
            icon: Icon(LucideIcons.pencil, size: 18),
            color: AppColors.textSecondary,
            tooltip: 'Editar',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(LucideIcons.trash2, size: 18),
            color: AppColors.error,
            tooltip: 'Excluir',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
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
