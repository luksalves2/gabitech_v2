import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../layouts/main_layout.dart';
import '../widgets/app_sidebar.dart';
import '../theme/app_colors.dart';
import '../../providers/assessor_providers.dart';
import '../../data/models/usuario.dart';

/// Página de gerenciamento de assessores
class AssessoresPage extends ConsumerStatefulWidget {
  const AssessoresPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AssessoresPage> createState() => _AssessoresPageState();
}

class _AssessoresPageState extends ConsumerState<AssessoresPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedMenuProvider.notifier).state = 'acessores';
      }
    });
  }

  void _openCadastroAssessor({Usuario? assessor}) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (_) => CadastroAssessorDialog(assessor: assessor),
      );
      if (!mounted) return;
      if (result == true) {
        // Recarregar lista de assessores
        ref.invalidate(assessoresProvider);
      }
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir diálogo: $e')),
      );
      print('Erro ao abrir CadastroAssessorDialog: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessoresAsync = ref.watch(assessoresProvider);
    final metrics = ref.watch(assessoresMetricsProvider);

    return MainLayout(
      title: 'Assessores',
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
                      Text(
                        'Assessores',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Gerencie a equipe do gabinete',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openCadastroAssessor(),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Novo Assessor'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Metric cards
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Total de assessores',
                    value: '${metrics['total'] ?? 0}',
                    icon: LucideIcons.users,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    title: 'Ativos',
                    value: '${metrics['ativos'] ?? 0}',
                    icon: LucideIcons.userCheck,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
            const SizedBox(height: 24),
            // Lista de assessores
            Expanded(
              child: assessoresAsync.when(
                data: (assessores) {
                  if (assessores.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.users,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum assessor cadastrado',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Clique em "Novo Assessor" para começar',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: assessores.length,
                    itemBuilder: (ctx, i) {
                      final assessor = assessores[i];
                      return _AssessorCard(
                        assessor: assessor,
                        onEdit: () => _openCadastroAssessor(
                          assessor: assessor,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erro ao carregar assessores',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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

/// Card de métrica
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  const _MetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
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
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de assessor
class _AssessorCard extends StatelessWidget {
  final Usuario assessor;
  final VoidCallback onEdit;

  const _AssessorCard({
    Key? key,
    required this.assessor,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isInativo = assessor.isAtivo != true;

    final avatarInitials = assessor.nome != null && assessor.nome!.isNotEmpty
        ? assessor.nome!.substring(0, 1).toUpperCase()
        : 'A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar e status
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  backgroundImage: assessor.avatar != null
                      ? NetworkImage(assessor.avatar!)
                      : null,
                  child: assessor.avatar == null
                      ? Text(
                          avatarInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isInativo
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInativo
                            ? LucideIcons.xCircle
                            : LucideIcons.checkCircle,
                        size: 14,
                        color: isInativo
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isInativo ? 'Inativo' : 'Ativo',
                        style: TextStyle(
                          color: isInativo
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Nome
            Text(
              assessor.nome ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Email
            Row(
              children: [
                Icon(LucideIcons.mail, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assessor.email ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Telefone
            Row(
              children: [
                Icon(LucideIcons.phone, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  assessor.telefone ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Cargo
            Row(
              children: [
                Icon(LucideIcons.briefcase,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assessor.cargo ?? 'Não informado',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Botão de editar permissões
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.settings, size: 16),
                label: const Text('Editar Permissões'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog de cadastro/edição de assessor
class CadastroAssessorDialog extends ConsumerStatefulWidget {
  final Usuario? assessor;

  const CadastroAssessorDialog({Key? key, this.assessor}) : super(key: key);

  @override
  ConsumerState<CadastroAssessorDialog> createState() =>
      _CadastroAssessorDialogState();
}

class _CadastroAssessorDialogState
    extends ConsumerState<CadastroAssessorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  // Máscara de telefone
  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) # ####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // Permissões
  bool _permDashboard = false;
  bool _permSolicitacoes = false;
  bool _permCidadaos = false;
  bool _permAtividades = false;
  bool _permTransmissoes = false;
  bool _permMensagens = false; // representa coluna atendimento
  bool _permAcessores = false;
  bool _ativo = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.assessor != null) {
      _nomeController.text = widget.assessor!.nome ?? '';
      _emailController.text = widget.assessor!.email ?? '';
      _telefoneController.text = widget.assessor!.telefone ?? '';
      _cargoController.text = widget.assessor!.cargo ?? '';
      _ativo = widget.assessor!.isAtivo;

      // Carregar permissões do assessor
      _permDashboard = widget.assessor!.dashboard ?? false;
      _permSolicitacoes = widget.assessor!.solicitacoes ?? false;
      _permCidadaos = widget.assessor!.cidadaos ?? false;
      _permAtividades = widget.assessor!.atividades ?? false;
      _permTransmissoes = widget.assessor!.transmissoes ?? false;
      _permMensagens = widget.assessor!.atendimento ?? false;
      _permAcessores = widget.assessor!.acessores ?? false;
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _cargoController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  /// Extrai mensagem de erro amigável
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Erros do Supabase Auth
    if (errorStr.contains('user already registered') ||
        errorStr.contains('user_already_exists')) {
      return 'Este e-mail já está cadastrado no sistema';
    }
    if (errorStr.contains('invalid email')) {
      return 'E-mail inválido';
    }
    if (errorStr.contains('password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    if (errorStr.contains('signup requires a valid password')) {
      return 'Informe uma senha válida';
    }

    // Erros de conexão
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Erro de conexão. Verifique sua internet';
    }

    // Erro genérico
    if (error is AuthException) {
      return error.message;
    }

    return 'Erro ao salvar. Tente novamente';
  }

  Future<void> _salvar() async {
    // Limpar erro anterior
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(assessorNotifierProvider.notifier);

      if (widget.assessor == null) {
        // Criar novo assessor
        await notifier.createAssessor(
          email: _emailController.text.trim(),
          password: _senhaController.text,
          nome: _nomeController.text.trim(),
          telefone: _telefoneController.text.trim(),
          cargo: _cargoController.text.trim(),
          dashboard: _permDashboard,
          solicitacoes: _permSolicitacoes,
          cidadaos: _permCidadaos,
          atividades: _permAtividades,
          transmissoes: _permTransmissoes,
          mensagens: _permMensagens,
          acessores: _permAcessores,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessor cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Atualizar assessor existente
        await notifier.updateAssessor(
          uuid: widget.assessor!.uuid,
          nome: _nomeController.text.trim(),
          telefone: _telefoneController.text.trim(),
          cargo: _cargoController.text.trim(),
          status: _ativo,
          dashboard: _permDashboard,
          solicitacoes: _permSolicitacoes,
          cidadaos: _permCidadaos,
          atividades: _permAtividades,
          transmissoes: _permTransmissoes,
          mensagens: _permMensagens,
          acessores: _permAcessores,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessor atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      final friendlyMessage = _getErrorMessage(e);
      setState(() => _errorMessage = friendlyMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMessage),
          backgroundColor: Colors.red,
        ),
      );
      // NÃO fecha o dialog em caso de erro - permite corrigir
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _excluir() async {
    if (widget.assessor == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir assessor'),
        content: Text(
          'Tem certeza que deseja excluir o assessor ${widget.assessor!.nome}? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(assessorNotifierProvider.notifier);
      await notifier.deleteAssessor(widget.assessor!.uuid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessor excluído com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.assessor != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              LucideIcons.userPlus,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEdicao
                                ? 'Editar Assessor'
                                : 'Cadastrar novo assessor',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mensagem de erro
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(LucideIcons.x,
                                size: 16, color: Colors.red.shade700),
                            onPressed: () =>
                                setState(() => _errorMessage = null),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Nome
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      hintText: 'ex: João Silva',
                      prefixIcon: Icon(LucideIcons.user),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),

                  // E-mail
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isEdicao, // Não permite editar email
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      hintText: 'ex: joao@gmail.com',
                      prefixIcon: const Icon(LucideIcons.mail),
                      helperText: isEdicao ? 'E-mail não pode ser alterado' : null,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      // Validação de email com regex
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(v)) {
                        return 'Informe um e-mail válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Telefone com máscara
                  TextFormField(
                    controller: _telefoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_telefoneMask],
                    decoration: const InputDecoration(
                      labelText: 'Telefone',
                      hintText: '(11) 9 9999-9999',
                      prefixIcon: Icon(LucideIcons.phone),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obrigatório';
                      // Verifica se tem pelo menos 14 caracteres (com máscara)
                      if (v.length < 14) {
                        return 'Telefone incompleto';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Cargo
                  TextFormField(
                    controller: _cargoController,
                    decoration: const InputDecoration(
                      labelText: 'Cargo',
                      hintText: 'ex: recepcionista',
                      prefixIcon: Icon(LucideIcons.briefcase),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Senha
                  TextFormField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEdicao
                          ? 'Senha (deixe em branco para não alterar)'
                          : 'Senha',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(LucideIcons.lock),
                      helperText: isEdicao ? null : 'Mínimo 6 caracteres',
                    ),
                    validator: (v) {
                      if (!isEdicao) {
                        if (v == null || v.isEmpty) {
                          return 'Obrigatório';
                        }
                        if (v.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Status (somente na edição)
                  if (isEdicao) ...[
                    SwitchListTile(
                      value: _ativo,
                      onChanged: (v) => setState(() => _ativo = v),
                      title: const Text('Assessor ativo'),
                      subtitle: Text(
                        _ativo
                            ? 'O assessor pode acessar o sistema'
                            : 'O assessor não pode acessar o sistema',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Permissões
                  const Text(
                    'Permissões de acesso',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _PermissionTile(
                          icon: LucideIcons.layoutDashboard,
                          label: 'Dashboard',
                          value: _permDashboard,
                          onChanged: (v) =>
                              setState(() => _permDashboard = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.clipboardList,
                          label: 'Solicitações',
                          value: _permSolicitacoes,
                          onChanged: (v) =>
                              setState(() => _permSolicitacoes = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.users,
                          label: 'Cidadãos',
                          value: _permCidadaos,
                          onChanged: (v) =>
                              setState(() => _permCidadaos = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.checkSquare,
                          label: 'Atividades',
                          value: _permAtividades,
                          onChanged: (v) =>
                              setState(() => _permAtividades = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.send,
                          label: 'Transmissões',
                          value: _permTransmissoes,
                          onChanged: (v) =>
                              setState(() => _permTransmissoes = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.messageSquare,
                          label: 'Mensagens',
                          value: _permMensagens,
                          onChanged: (v) =>
                              setState(() => _permMensagens = v ?? false),
                        ),
                        _PermissionTile(
                          icon: LucideIcons.userCog,
                          label: 'Assessores',
                          value: _permAcessores,
                          onChanged: (v) =>
                              setState(() => _permAcessores = v ?? false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botão de excluir (somente na edição)
                      if (isEdicao)
                        TextButton.icon(
                          onPressed: _isLoading ? null : _excluir,
                          icon: const Icon(LucideIcons.trash2, size: 16),
                          label: const Text('Excluir'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        )
                      else
                        const SizedBox.shrink(),

                      Row(
                        children: [
                          TextButton(
                            onPressed:
                                _isLoading ? null : () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _salvar,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(LucideIcons.save),
                            label: Text(isEdicao ? 'Salvar' : 'Cadastrar'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile de permissão
class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _PermissionTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
