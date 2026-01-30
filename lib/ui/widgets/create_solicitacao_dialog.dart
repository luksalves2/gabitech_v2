import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../data/models/cidadao.dart';
import '../../data/models/categoria_tarefa.dart';
import '../../providers/cidadao_providers.dart';
import '../../providers/solicitacao_providers.dart';
import '../../providers/tarefa_providers.dart';
import '../../providers/core_providers.dart';
import '../theme/app_colors.dart';
import 'cached_avatar.dart';

/// Dialog para criar nova solicitação
class CreateSolicitacaoDialog extends ConsumerStatefulWidget {
  final Cidadao? cidadaoPreSelecionado;

  const CreateSolicitacaoDialog({super.key, this.cidadaoPreSelecionado});

  @override
  ConsumerState<CreateSolicitacaoDialog> createState() => _CreateSolicitacaoDialogState();
}

class _CreateSolicitacaoDialogState extends ConsumerState<CreateSolicitacaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _resumoController = TextEditingController();
  final _cidadaoSearchController = TextEditingController();
  
  Cidadao? _selectedCidadao;
  String _prioridade = 'Média';
  CategoriaTarefa? _selectedCategoria;
  DateTime? _prazo;
  int? _prazoPadraoDias;
  String? _selectedAcessor;
  String? _selectedAcessorNome;
  bool _isLoading = false;
  bool _showCidadaoSearch = false;

  @override
  void initState() {
    super.initState();
    if (widget.cidadaoPreSelecionado != null) {
      _selectedCidadao = widget.cidadaoPreSelecionado;
      _showCidadaoSearch = false;
    }
    _preFillAcessor();
    _aplicarPrazoPadrao();
  }

  /// Carrega o prazo padrão do gabinete (perfil) e pré-preenche a data,
  /// mas permite que o usuário altere manualmente.
  Future<void> _aplicarPrazoPadrao() async {
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (!mounted) return;
    _prazoPadraoDias = gabinete?.prazoSolicitacoes;

    if (_prazo == null && _prazoPadraoDias != null) {
      setState(() {
        _prazo = DateTime.now().add(Duration(days: _prazoPadraoDias!));
      });
    }
  }

  /// Pré-seleciona o usuário logado como assessor e exibe o nome
  Future<void> _preFillAcessor() async {
    final user = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    setState(() {
      _selectedAcessor = user?.uuid;
      _selectedAcessorNome = user?.nome;
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _resumoController.dispose();
    _cidadaoSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cidadaosAsync = ref.watch(cidadaosProvider(CidadaosParams(
      searchTerm: _cidadaoSearchController.text,
      limit: 10,
    )));
    
    final currentUser = ref.watch(currentUserProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    'Criar solicitação',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.cidadaoPreSelecionado == null) ...[
                        // Cidadão
                        _buildLabel('Cidadão *'),
                        const SizedBox(height: 8),
                        _buildCidadaoSelector(cidadaosAsync),
                        const SizedBox(height: 20),
                      ] else ...[
                        _buildLabel('Cidadão'),
                        const SizedBox(height: 8),
                        _SelectedCidadaoTile(cidadao: widget.cidadaoPreSelecionado!),
                        const SizedBox(height: 20),
                      ],
                      
                      // Título
                      _buildLabel('Título'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _tituloController,
                        decoration: _inputDecoration('Ex: Pedido de lombada'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Título é obrigatório';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Descrição
                      _buildLabel('Descrição'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descricaoController,
                        decoration: _inputDecoration('Descreva a solicitação em detalhes...'),
                        maxLines: 4,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Resumo
                      _buildLabel('Resumo da conversa'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _resumoController,
                        decoration: _inputDecoration('Descreva o resumo da conversa').copyWith(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.warning, width: 2),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Acessor and Prazo row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Acessor'),
                                const SizedBox(height: 8),
                                currentUser.when(
                                  data: (user) {
                                    // Auto-select current user as accessor
                                    _selectedAcessor ??= user?.uuid;
                                    _selectedAcessorNome ??= user?.nome;
                                    
                                    return DropdownButtonFormField<String>(
                                      value: _selectedAcessor,
                                      decoration: _inputDecoration('Selecione'),
                                      isExpanded: true,
                                      items: [
                                        if (user != null)
                                          DropdownMenuItem(
                                            value: user.uuid,
                                            child: Text(
                                              user.nome ?? 'Usuário',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedAcessor = value;
                                          _selectedAcessorNome = user?.nome;
                                        });
                                      },
                                    );
                                  },
                                  loading: () => const CircularProgressIndicator(),
                                  error: (_, __) => const Text('Erro'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Prazo Final'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectPrazo,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(10),
                                      color: AppColors.surface,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _prazo != null 
                                                ? DateFormat('dd/MM/yyyy').format(_prazo!)
                                                : 'Selecione a data',
                                            style: TextStyle(
                                              color: _prazo != null 
                                                  ? AppColors.textPrimary 
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          LucideIcons.calendar,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Prioridade
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Prioridade'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPriorityChip('Alta'),
                              _buildPriorityChip('Média'),
                              _buildPriorityChip('Baixa'),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Categoria
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Categoria'),
                          const SizedBox(height: 8),
                          _buildCategoriaDropdown(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Criar solicitação'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildCidadaoSelector(AsyncValue<List<Cidadao>> cidadaosAsync) {
    if (_selectedCidadao != null && !_showCidadaoSearch) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            CachedAvatar(
              radius: 18,
              imageUrl: _selectedCidadao?.foto,
              name: _selectedCidadao?.nome,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCidadao!.nome ?? 'Cidadão',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_selectedCidadao!.telefone != null)
                    Text(
                      _formatTelefone(_selectedCidadao!.telefone!),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedCidadao = null;
                  _showCidadaoSearch = true;
                });
              },
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        TextFormField(
          controller: _cidadaoSearchController,
          decoration: _inputDecoration('Buscar cidadão por nome ou telefone').copyWith(
            prefixIcon: const Icon(LucideIcons.search, size: 18),
          ),
          onChanged: (value) => setState(() {}),
          validator: (value) {
            if (_selectedCidadao == null) {
              return 'Selecione um cidadão';
            }
            return null;
          },
        ),
        if (_cidadaoSearchController.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: cidadaosAsync.when(
              data: (cidadaos) {
                if (cidadaos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum cidadão encontrado'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: cidadaos.length,
                  itemBuilder: (context, index) {
                    final cidadao = cidadaos[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          cidadao.nome?.substring(0, 1).toUpperCase() ?? 'C',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(cidadao.nome ?? 'Cidadão'),
                      subtitle: Text(cidadao.telefone != null ? _formatTelefone(cidadao.telefone!) : ''),
                      onTap: () {
                        setState(() {
                          _selectedCidadao = cidadao;
                          _cidadaoSearchController.clear();
                          _showCidadaoSearch = false;
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Erro ao buscar cidadãos'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriorityChip(String label) {
    final isSelected = _prioridade == label;
    Color color;
    IconData icon;
    
    switch (label) {
      case 'Alta':
        color = AppColors.error;
        icon = LucideIcons.alertCircle;
        break;
      case 'Média':
        color = AppColors.warning;
        icon = LucideIcons.alertCircle;
        break;
      case 'Baixa':
      default:
        color = AppColors.textTertiary;
        icon = LucideIcons.alertCircle;
        break;
    }

    return InkWell(
      onTap: () => setState(() => _prioridade = label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaDropdown() {
    final categoriasAsync = ref.watch(categoriasTarefasProvider);
    
    return categoriasAsync.when(
      data: (categorias) {
        if (categorias.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
              color: AppColors.surfaceVariant,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertCircle, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Text(
                  'Nenhuma categoria cadastrada',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        
        return DropdownButtonFormField<CategoriaTarefa>(
          value: _selectedCategoria,
          decoration: _inputDecoration('Selecione'),
          isExpanded: true,
          items: categorias.map((cat) {
            return DropdownMenuItem<CategoriaTarefa>(
              value: cat,
              child: Text(cat.nome, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedCategoria = value);
          },
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Carregando categorias...'),
          ],
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.error),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Erro ao carregar categorias',
          style: TextStyle(color: AppColors.error),
        ),
      ),
    );
  }

  Future<void> _selectPrazo() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _prazo ??
          DateTime.now().add(Duration(days: _prazoPadraoDias ?? 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() => _prazo = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCidadao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cidadão')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(solicitacaoNotifierProvider.notifier).create(
        cidadaoId: _selectedCidadao!.id,
        titulo: _tituloController.text,
        descricao: _descricaoController.text.isNotEmpty ? _descricaoController.text : null,
        resumo: _resumoController.text.isNotEmpty ? _resumoController.text : null,
        prioridade: _prioridade,
        categoriaId: _selectedCategoria?.id,
        categoria: _selectedCategoria?.nome,
        prazo: _prazo != null ? DateFormat('dd/MM/yyyy').format(_prazo!) : null,
        acessor: _selectedAcessor,
        nomeAcessor: _selectedAcessorNome,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

class _SelectedCidadaoTile extends StatelessWidget {
  final Cidadao cidadao;
  const _SelectedCidadaoTile({required this.cidadao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CachedAvatar(
            radius: 22,
            imageUrl: cidadao.foto,
            name: cidadao.nome ?? '',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cidadao.nome ?? 'Cidadão',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (cidadao.telefone != null)
                  Text(
                    cidadao.telefone!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
