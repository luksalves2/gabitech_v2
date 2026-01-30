import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import '../theme/app_colors.dart';
import '../../providers/cidadao_providers.dart';
import '../../providers/core_providers.dart';
import '../../data/models/cidadao.dart';
import '../../data/services/viacep_service.dart';

/// Dialog for creating/editing a citizen
class CidadaoFormDialog extends ConsumerStatefulWidget {
  final Cidadao? cidadao; // null = create, not null = edit
  final String? initialPhone; // For pre-filling phone from chat
  final String? initialName;
  final Function(Cidadao)? onSaved;

  const CidadaoFormDialog({
    super.key,
    this.cidadao,
    this.initialPhone,
    this.initialName,
    this.onSaved,
  });

  @override
  ConsumerState<CidadaoFormDialog> createState() => _CidadaoFormDialogState();
}
// =====================
// INPUT FORMATTERS (global)
// =====================

/// Formata a data enquanto digita para dd/MM/yyyy
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Formata CEP para 00000-000
class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length && i < 8; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Formata UF para 2 letras maiúsculas
class _UfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    if (text.length > 2) text = text.substring(0, 2);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Formata telefone brasileiro (com DDD) para (XX) XXXXX-XXXX ou (XX) XXXX-XXXX
class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 11) text = text.substring(0, 11);
    String formatted = '';
    if (text.length >= 2) {
      formatted += '(${text.substring(0, 2)}) ';
      if (text.length >= 7) {
        if (text.length == 11) {
          formatted += text.substring(2, 7) + '-' + text.substring(7);
        } else {
          formatted += text.substring(2, 6) + '-' + text.substring(6);
        }
      } else if (text.length > 2) {
        formatted += text.substring(2);
      }
    } else {
      formatted = text;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CidadaoFormDialogState extends ConsumerState<CidadaoFormDialog> {
  /// Formata telefone vindo do banco/whatsapp para exibiÃ§Ã£o no input
  String _formatTelefoneInicial(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var cleaned = raw.replaceAll('@s.whatsapp.net', '');
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('55') && cleaned.length > 11) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.length > 11) cleaned = cleaned.substring(0, 11);
    if (cleaned.length == 11) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    }
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    }
    return cleaned;
  }

  /// Normaliza data ISO (yyyy-MM-dd) para dd/MM/yyyy
  String _formatDateIfNeeded(String? value) {
    if (value == null || value.isEmpty) return '';
    try {
      final dt = DateTime.parse(value);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return value;
    }
  }

  /// Preenche controladores vazios com dados completos do cidadÃ£o
  void _hydrateControllers(Cidadao full) {
    final generoFromDb = full.genero?.trim();
    String generoValue = _selectedGenero ?? '';
    if ((generoValue.isEmpty) && generoFromDb != null && generoFromDb.isNotEmpty) {
      if (generoFromDb.toUpperCase() == 'M' || generoFromDb.toLowerCase() == 'masculino') generoValue = 'Masculino';
      else if (generoFromDb.toUpperCase() == 'F' || generoFromDb.toLowerCase() == 'feminino') generoValue = 'Feminino';
      else if (generoFromDb.toUpperCase() == 'O' || generoFromDb.toLowerCase() == 'outro') generoValue = 'Outro';
      else generoValue = generoFromDb;
    }

    setState(() {
      if (_nomeController.text.trim().isEmpty && (full.nome?.isNotEmpty ?? false)) {
        _nomeController.text = full.nome!;
      }
      if (_emailController.text.trim().isEmpty && (full.email?.isNotEmpty ?? false)) {
        _emailController.text = full.email!;
      }
      final formattedPhone = _formatTelefoneInicial(full.telefone);
      if (_telefoneController.text.trim().isEmpty && formattedPhone.isNotEmpty) {
        _telefoneController.text = formattedPhone;
      }
      final formattedDate = _formatDateIfNeeded(full.dataNascimento);
      if (_dataNascimentoController.text.trim().isEmpty && formattedDate.isNotEmpty) {
        _dataNascimentoController.text = formattedDate;
      }
      if (_cepController.text.trim().isEmpty && (full.cep?.isNotEmpty ?? false)) {
        _cepController.text = full.cep!;
      }
      if (_ruaController.text.trim().isEmpty && (full.rua?.isNotEmpty ?? false)) {
        _ruaController.text = full.rua!;
      }
      if (_bairroController.text.trim().isEmpty && (full.bairro?.isNotEmpty ?? false)) {
        _bairroController.text = full.bairro!;
      }
      if (_cidadeController.text.trim().isEmpty && (full.cidade?.isNotEmpty ?? false)) {
        _cidadeController.text = full.cidade!;
      }
      if (_estadoController.text.trim().isEmpty && (full.estado?.isNotEmpty ?? false)) {
        _estadoController.text = full.estado!;
      }
      if (_numeroController.text.trim().isEmpty && (full.numeroResidencia?.isNotEmpty ?? false)) {
        _numeroController.text = full.numeroResidencia!;
      }
      if (_complementoController.text.trim().isEmpty && (full.complemento?.isNotEmpty ?? false)) {
        _complementoController.text = full.complemento!;
      }
      if (_referenciaController.text.trim().isEmpty && (full.pontoReferencia?.isNotEmpty ?? false)) {
        _referenciaController.text = full.pontoReferencia!;
      }
      if (_perfilController.text.trim().isEmpty && (full.perfil?.isNotEmpty ?? false)) {
        _perfilController.text = full.perfil!;
      }
      if ((_selectedGenero == null || _selectedGenero!.isEmpty) && generoValue.isNotEmpty) {
        _selectedGenero = generoValue;
      }
    });
  }

  late final TextEditingController _telefoneController;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _emailController;
  late final TextEditingController _dataNascimentoController;
  late final TextEditingController _cepController;
  late final TextEditingController _ruaController;
  late final TextEditingController _bairroController;
  late final TextEditingController _cidadeController;
  late final TextEditingController _estadoController;
  late final TextEditingController _numeroController;
  late final TextEditingController _complementoController;
  late final TextEditingController _referenciaController;
  late final TextEditingController _perfilController;

  String? _selectedGenero;
  bool _isLoading = false;
  bool _isLoadingCep = false;

  final List<String> _generos = ['Masculino', 'Feminino', 'Outro', 'Prefiro não informar'];

  @override
  void initState() {
    super.initState();
    final c = widget.cidadao;
    _telefoneController = TextEditingController(
      text: _formatTelefoneInicial(c?.telefone ?? widget.initialPhone),
    );
    
    // Nome: usa cidadao.nome, senão usa initialName
    String initialNome = '';
    if (c?.nome != null && c!.nome!.isNotEmpty) {
      initialNome = c.nome!;
    } else if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      initialNome = widget.initialName!;
    }
    
    _nomeController = TextEditingController(text: initialNome);
    _emailController = TextEditingController(text: c?.email ?? '');
    _dataNascimentoController = TextEditingController(text: c?.dataNascimento ?? '');
    _cepController = TextEditingController(text: c?.cep ?? '');
    _ruaController = TextEditingController(text: c?.rua ?? '');
    _bairroController = TextEditingController(text: c?.bairro ?? '');
    _cidadeController = TextEditingController(text: c?.cidade ?? '');
    _estadoController = TextEditingController(text: c?.estado ?? '');
    _numeroController = TextEditingController(text: c?.numeroResidencia ?? '');
    _complementoController = TextEditingController(text: c?.complemento ?? '');
    _referenciaController = TextEditingController(text: c?.pontoReferencia ?? '');
    _perfilController = TextEditingController(text: c?.perfil ?? '');
    _selectedGenero = c?.genero;
    
    // Adicionar listener para buscar CEP automaticamente
    _cepController.addListener(_onCepChanged);

    // If some fields are missing (sometimes nested join doesn't include all columns),
    // fetch the full Cidadao from repository and fill them.
    if (c != null) {
      Future.microtask(() async {
        try {
          final repo = ref.read(cidadaoRepositoryProvider);
          final full = await repo.getById(c.id);
          if (full != null && mounted) {
            _hydrateControllers(full);
          }
        } catch (_) {
          // ignore errors silently, UI will continue with existing values
        }
      });
    }
  }
  
  void _onCepChanged() {
    final cep = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cep.length == 8) {
      _buscarCep(cep);
    }
  }
  
  Future<void> _buscarCep(String cep) async {
    if (_isLoadingCep) return;
    
    setState(() => _isLoadingCep = true);
    
    try {
      final result = await ViaCepService.buscarCep(cep);
      
      if (result != null && mounted) {
        setState(() {
          _ruaController.text = result.logradouro;
          _bairroController.text = result.bairro;
          _cidadeController.text = result.localidade;
          _estadoController.text = result.uf;
          if (result.complemento.isNotEmpty && _complementoController.text.isEmpty) {
            _complementoController.text = result.complemento;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCep = false);
      }
    }
  }

  @override
  void dispose() {
      _telefoneController.dispose();
    _cepController.removeListener(_onCepChanged);
    _nomeController.dispose();
    _emailController.dispose();
    _dataNascimentoController.dispose();
    _cepController.dispose();
    _ruaController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _referenciaController.dispose();
    _perfilController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    
    final isEditing = widget.cidadao != null;
    
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
                    isEditing ? 'Editar cidadão' : 'Cadastro cidadão',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome
                      _buildLabel('Nome'),
                      _buildTextField(
                        controller: _nomeController,
                        hint: 'Nome completo',
                        validator: (v) => v?.isEmpty == true ? 'Nome é obrigatório' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildLabel('E-mail'),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'ex: joao@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Telefone
                      _buildLabel('Telefone'),
                      _buildTextField(
                        controller: _telefoneController,
                        hint: 'ex: (47) 99999-9999',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          _TelefoneInputFormatter(),
                        ],
                        // Em edição a partir da tela de mensagens o número já está salvo no banco,
                        // então deixamos somente leitura para evitar inconsistências.
                        readOnly: isEditing || widget.initialPhone != null,
                      ),
                      const SizedBox(height: 16),



                      // Data de Nascimento
                      _buildLabel('Data de Nascimento'),
                      _buildTextField(
                        controller: _dataNascimentoController,
                        hint: 'ex: 21/08/1991',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          // Formata como dd/MM/yyyy
                          _DateInputFormatter(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // CEP
                      _buildLabel('CEP'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cepController,
                              hint: 'ex: 12345-123',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                _CepInputFormatter(),
                              ],
                            ),
                          ),
                          if (_isLoadingCep) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isLoadingCep)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Buscando endereço...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Rua e Bairro
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Rua'),
                                _buildTextField(
                                  controller: _ruaController,
                                  hint: 'ex: Logo ali',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Bairro'),
                                _buildTextField(
                                  controller: _bairroController,
                                  hint: 'ex: Centro',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cidade, Estado, Numero
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Cidade'),
                                _buildTextField(
                                  controller: _cidadeController,
                                  hint: 'ex: São Paulo',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Estado'),
                                _buildTextField(
                                  controller: _estadoController,
                                  hint: 'ex: SP',
                                  inputFormatters: [
                                    _UfInputFormatter(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Numero'),
                                _buildTextField(
                                  controller: _numeroController,
                                  hint: 'ex: 204',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Complemento e Referencia
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Complemento'),
                                _buildTextField(
                                  controller: _complementoController,
                                  hint: 'ex: APTO 204',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Referência'),
                                _buildTextField(
                                  controller: _referenciaController,
                                  hint: 'ex: Mercadinho',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Gênero
                      _buildLabel('Gênero'),
                      DropdownButtonFormField<String>(
                        value: _selectedGenero,
                        hint: const Text('Selecione'),
                        decoration: _dropdownDecoration,
                        items: _generos.map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedGenero = v),
                      ),
                      const SizedBox(height: 16),

                      // Perfil
                      _buildLabel('Perfil'),
                      _buildTextField(
                        controller: _perfilController,
                        hint: 'ex: Jornalista, Repórter...',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Salvar'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  InputDecoration get _dropdownDecoration => InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceVariant,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(cidadaoNotifierProvider.notifier);
      final latLng = await _geocodeIfNeeded();
      
      if (widget.cidadao != null) {
        // Update existing
        await notifier.update(
          id: widget.cidadao!.id,
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          telefone: _telefoneController.text.trim().isNotEmpty ? _telefoneController.text.trim() : null,
          dataNascimento: _dataNascimentoController.text.trim().isNotEmpty ? _dataNascimentoController.text.trim() : null,
          genero: _selectedGenero,
          bairro: _bairroController.text.trim().isNotEmpty ? _bairroController.text.trim() : null,
          cep: _cepController.text.trim().isNotEmpty ? _cepController.text.trim() : null,
          rua: _ruaController.text.trim().isNotEmpty ? _ruaController.text.trim() : null,
          cidade: _cidadeController.text.trim().isNotEmpty ? _cidadeController.text.trim() : null,
          estado: _estadoController.text.trim().isNotEmpty ? _estadoController.text.trim() : null,
          numeroResidencia: _numeroController.text.trim().isNotEmpty ? _numeroController.text.trim() : null,
          complemento: _complementoController.text.trim().isNotEmpty ? _complementoController.text.trim() : null,
          pontoReferencia: _referenciaController.text.trim().isNotEmpty ? _referenciaController.text.trim() : null,
          perfil: _perfilController.text.trim().isNotEmpty ? _perfilController.text.trim() : null,
          latitude: latLng?['lat'],
          longitude: latLng?['lng'],
        );
        
        // After updating, fetch fresh cidadao and notify caller so it can refresh
        final updatedCidadao = await ref.read(cidadaoProvider(widget.cidadao!.id).future);
        if (mounted) {
          Navigator.pop(context);
          if (updatedCidadao != null) {
            widget.onSaved?.call(updatedCidadao);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cidadão atualizado com sucesso!')),
          );
        }
      } else {
        // Create new
        final cidadao = await notifier.create(
          nome: _nomeController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          telefone: _telefoneController.text.trim().isNotEmpty ? _telefoneController.text.trim() : null,
          dataNascimento: _dataNascimentoController.text.trim().isNotEmpty ? _dataNascimentoController.text.trim() : null,
          genero: _selectedGenero,
          perfil: _perfilController.text.trim().isNotEmpty ? _perfilController.text.trim() : null,
          bairro: _bairroController.text.trim().isNotEmpty ? _bairroController.text.trim() : null,
          cep: _cepController.text.trim().isNotEmpty ? _cepController.text.trim() : null,
          rua: _ruaController.text.trim().isNotEmpty ? _ruaController.text.trim() : null,
          cidade: _cidadeController.text.trim().isNotEmpty ? _cidadeController.text.trim() : null,
          estado: _estadoController.text.trim().isNotEmpty ? _estadoController.text.trim() : null,
          numeroResidencia: _numeroController.text.trim().isNotEmpty ? _numeroController.text.trim() : null,
          complemento: _complementoController.text.trim().isNotEmpty ? _complementoController.text.trim() : null,
          pontoReferencia: _referenciaController.text.trim().isNotEmpty ? _referenciaController.text.trim() : null,
          latitude: latLng?['lat'],
          longitude: latLng?['lng'],
        );
        
        if (mounted) {
          Navigator.pop(context);
          if (cidadao != null) {
            widget.onSaved?.call(cidadao);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cidadão cadastrado com sucesso!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Geocodifica o endereço/CEP para preencher latitude e longitude.
  /// Só dispara se não houver lat/lng já cadastrados.
  Future<Map<String, String>?> _geocodeIfNeeded() async {
    // Se já existe lat/lng no cidadão, não recalcula
    if (widget.cidadao?.latitude?.isNotEmpty == true &&
        widget.cidadao?.longitude?.isNotEmpty == true) {
      return null;
    }

    final rua = _ruaController.text.trim();
    final numero = _numeroController.text.trim();
    final bairro = _bairroController.text.trim();
    final cidade = _cidadeController.text.trim();
    final estado = _estadoController.text.trim();
    final cep = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    String query = '';
    if (rua.isNotEmpty) {
      query = '$rua ${numero.isNotEmpty ? numero : ''} $bairro $cidade $estado Brasil';
    } else if (cep.length == 8) {
      query = cep;
    } else {
      return null;
    }

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=br',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Gabitech/2.0 geocoder',
        'Accept': 'application/json',
      });
      if (response.statusCode != 200) return null;
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final first = data.first as Map<String, dynamic>;
      final lat = first['lat']?.toString();
      final lng = first['lon']?.toString();
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }
}

/// Show the cidadao form dialog
Future<void> showCidadaoFormDialog(
  BuildContext context, {
  Cidadao? cidadao,
  String? initialPhone,
  String? initialName,
  Function(Cidadao)? onSaved,
}) {
  return showDialog(
    context: context,
    builder: (context) => CidadaoFormDialog(
      cidadao: cidadao,
      initialPhone: initialPhone,
      initialName: initialName,
      onSaved: onSaved,
    ),
  );
}
