import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/core_providers.dart';
import '../../theme/app_colors.dart';

class CriarContaPage extends ConsumerStatefulWidget {
  const CriarContaPage({super.key});

  @override
  ConsumerState<CriarContaPage> createState() => _CriarContaPageState();
}

class _CriarContaPageState extends ConsumerState<CriarContaPage> {
  final _formKey = GlobalKey<FormState>();
  final _gabineteNomeController = TextEditingController();
  final _gabineteDescricaoController = TextEditingController();
  final _gabineteTelefoneController = TextEditingController();
  final _gabineteCidadeController = TextEditingController();
  final _gabineteEstadoController = TextEditingController();
  final _pessoaNomeController = TextEditingController();
  final _pessoaEmailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _gabineteNomeController.dispose();
    _gabineteDescricaoController.dispose();
    _gabineteTelefoneController.dispose();
    _gabineteCidadeController.dispose();
    _gabineteEstadoController.dispose();
    _pessoaNomeController.dispose();
    _pessoaEmailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String _normalizeTelefone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('55')) {
      final prefix = digits.substring(0, 4);
      final rest = digits.substring(4);
      if (rest.length == 9 && rest.startsWith('9')) {
        return prefix + rest.substring(1);
      }
    }
    return digits;
  }

  bool _isValidTelefone(String value) {
    final normalized = _normalizeTelefone(value);
    return RegExp(r'^55\d{10}$').hasMatch(normalized);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? authUserId;
    try {
      debugPrint('[CADASTRO] submit start');
      final cadastroRepo = ref.read(cadastroRepositoryProvider);
      final supabase = ref.read(supabaseClientProvider);

      final telefoneNormalizado =
          _normalizeTelefone(_gabineteTelefoneController.text.trim());
      final descricao = _gabineteDescricaoController.text.trim();

      debugPrint('[CADASTRO] signUp email=${_pessoaEmailController.text.trim()}');
      final authResponse = await supabase.auth.signUp(
        email: _pessoaEmailController.text.trim(),
        password: _senhaController.text,
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        debugPrint('[CADASTRO] auth user null');
        throw Exception('Falha ao criar usuário de autenticação');
      }
      authUserId = authUser.id;
      debugPrint('[CADASTRO] auth user id=$authUserId');

      final gabineteId = await cadastroRepo.createGabinete(
        nome: _gabineteNomeController.text.trim(),
        descricao: descricao.isEmpty ? null : descricao,
        telefone: telefoneNormalizado,
        cidade: _gabineteCidadeController.text.trim(),
        estado: _gabineteEstadoController.text.trim(),
        usuarioUuid: authUserId,
      );
      debugPrint('[CADASTRO] gabinete criado id=$gabineteId');

      await cadastroRepo.createUsuarioVereador(
        gabineteId: gabineteId,
        nome: _pessoaNomeController.text.trim(),
        email: _pessoaEmailController.text.trim(),
        telefone: telefoneNormalizado,
        usuarioUuid: authUserId,
      );
      debugPrint('[CADASTRO] usuario vereador criado');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gabinete criado com sucesso! Agora faça login.'),
        ),
      );

      debugPrint('[CADASTRO] forcing signOut');
      await _forceSignOut(supabase);
      await _waitForSignedOut(supabase);
      authUserId = null;
      if (!mounted) return;
      debugPrint('[CADASTRO] invalidating providers and going to login');
      ref.invalidate(currentUserProvider);
      ref.invalidate(currentGabineteProvider);
      context.go('/login?force=true');
    } catch (error) {
      debugPrint('[CADASTRO] error: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      if (authUserId != null) {
        try {
          final supabase = ref.read(supabaseClientProvider);
          debugPrint('[CADASTRO] finalizer signOut');
          await _forceSignOut(supabase);
          await _waitForSignedOut(supabase);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _waitForSignedOut(SupabaseClient supabase) async {
    if (supabase.auth.currentSession == null) {
      debugPrint('[CADASTRO] session already null');
      return;
    }
    debugPrint('[CADASTRO] waiting for signed out event...');
    final completer = Completer<void>();
    late final StreamSubscription<AuthState> sub;
    sub = supabase.auth.onAuthStateChange.listen((state) {
      if (state.session == null && !completer.isCompleted) {
        completer.complete();
      }
    });

    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 2)),
    ]);
    await sub.cancel();
    if (supabase.auth.currentSession != null) {
      debugPrint('[CADASTRO] session still present, forcing local signOut');
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    debugPrint(
      '[CADASTRO] signed out? session=${supabase.auth.currentSession == null}',
    );
  }
  Future<void> _forceSignOut(SupabaseClient supabase) async {
    try {
      debugPrint('[CADASTRO] signOut global');
      await supabase.auth.signOut(scope: SignOutScope.global);
    } catch (_) {
      try {
        debugPrint('[CADASTRO] signOut default');
        await supabase.auth.signOut();
      } catch (_) {}
    }
    if (supabase.auth.currentSession != null) {
      try {
        debugPrint('[CADASTRO] signOut local (session still present)');
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {}
    }
  }

  String _formatError(Object error) {
    final message = error.toString();
    if (message.isEmpty) return 'Erro inesperado';
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.85),
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 280,
                          height: 280,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Crie seu Gabinete',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cadastre um gabinete, vincule um cidadão responsável e comece a organizar sua equipe.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Criar conta',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Informe os dados do gabinete e da pessoa responsável para criar o cadastro.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 32),
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          'Gabinete',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _gabineteNomeController,
                          decoration: InputDecoration(
                            labelText: 'Nome do gabinete',
                            prefixIcon: const Icon(LucideIcons.building2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome do gabinete';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _gabineteDescricaoController,
                          decoration: InputDecoration(
                            labelText: 'Descrição do gabinete',
                            hintText: 'Um resumo breve da missão ou área',
                            prefixIcon: const Icon(LucideIcons.info),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe a descrição do gabinete';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
        TextFormField(
          controller: _gabineteTelefoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Telefone',
            hintText: '554792071963',
            prefixIcon: const Icon(LucideIcons.phone),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o telefone do gabinete';
            }
            if (!_isValidTelefone(value)) {
              return 'Telefone deve estar no formato 554792071963';
            }
            return null;
          },
        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _gabineteCidadeController,
                          decoration: InputDecoration(
                            labelText: 'Cidade',
                            prefixIcon: const Icon(LucideIcons.mapPin),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe a cidade do gabinete';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _gabineteEstadoController,
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            prefixIcon: const Icon(LucideIcons.flag),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o estado do gabinete';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Pessoa de contato',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pessoaNomeController,
                          decoration: InputDecoration(
                            labelText: 'Nome completo',
                            prefixIcon: const Icon(LucideIcons.user),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome da pessoa';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
        TextFormField(
          controller: _pessoaEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail',
            hintText: 'contato@meugabinete.gov.br',
            prefixIcon: const Icon(LucideIcons.mail),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o e-mail da pessoa';
            }
            final email = value.trim();
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
              return 'E-mail invalido';
            }
            return null;
          },
        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _senhaController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            prefixIcon: const Icon(LucideIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe a senha';
                            }
                            if (value.length < 6) {
                              return 'A senha deve ter pelo menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmarSenhaController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmar senha',
                            prefixIcon: const Icon(LucideIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirme a senha';
                            }
                            if (value != _senhaController.text) {
                              return 'As senhas não coincidem';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Criar conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Voltar para o login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

