import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../../providers/core_providers.dart';
import '../../../data/models/gabinete.dart';

/// Pagina de perfil do usuario
class PerfilPage extends ConsumerStatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _prazoSolicitacoesController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingFoto = false;
  String? _avatarUrl;
  String _waStatus = 'disconnected';
  String? _waPaircode;
  bool _waLoading = false;
  Gabinete? _gabinete;
  String? _instanceToken;
  bool _primeiroAcesso = false;
  String? _usuarioUuid;

  Timer? _statusPollingTimer;
  Timer? _qrTimer;
  int _qrSecondsLeft = 120;
  bool _qrModalOpen = false;
  String? _qrData;
  bool _qrExpired = false;
  void Function(void Function())? _modalSetState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(selectedMenuProvider.notifier).state = 'perfil';
        _loadUserData();
      }
    });
  }

  void _loadUserData() {
    final currentUser = ref.read(currentUserProvider);
    final currentGabinete = ref.read(currentGabineteProvider);

    currentUser.whenData((user) {
      if (user != null) {
        _nomeController.text = user.nome ?? '';
        _cargoController.text = user.cargo ?? '';
        _emailController.text = user.email ?? '';
        _telefoneController.text = _formatPhone(user.telefone ?? '');
        _avatarUrl = user.foto;
        _primeiroAcesso = user.primeiroAcesso ?? false;
        _usuarioUuid = user.uuid;
      }
    });

    currentGabinete.whenData((gabinete) {
      if (gabinete != null) {
        setState(() {
          _gabinete = gabinete;
          _instanceToken = gabinete.token;
          _enderecoController.text = gabinete.endereco ?? '';
          _prazoSolicitacoesController.text = gabinete.prazoSolicitacoes?.toString() ?? '21';
        });
        if ((_instanceToken?.isNotEmpty ?? false)) {
          _refreshWhatsappStatus(silent: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cargoController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _enderecoController.dispose();
    _prazoSolicitacoesController.dispose();
    _statusPollingTimer?.cancel();
    _qrTimer?.cancel();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) throw 'Usuario nao encontrado';

      final repo = ref.read(usuarioRepositoryProvider);
      await repo.updateUsuario(
        uuid: user.uuid,
        nome: _nomeController.text.trim(),
        cargo: _cargoController.text.trim(),
        email: _emailController.text.trim(),
        telefone: user.telefone, // telefone nao editavel aqui
      );

      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil atualizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _alterarSenha() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _AlterarSenhaDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha alterada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _abrirSuporteWhatsapp() async {
    final url = Uri.parse('https://wa.me/5547992071963?text=Ola, preciso de suporte tecnico no sistema Gabitech.');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel abrir o WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshWhatsappStatus({bool silent = false}) async {
    final token = _instanceToken;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _waStatus = 'disconnected';
          _waPaircode = null;
          _qrData = null;
        });
      }
      return;
    }

    try {
      if (!silent) setState(() => _waLoading = true);
      final statusResp = await ref.read(uazapiServiceProvider).statusInstancia(token);
      if (!mounted) return;

      if (statusResp.isSuccess && statusResp.data != null) {
        final statusData = statusResp.data!;
        final st = (statusData.status ?? (statusData.connected ? 'connected' : 'disconnected'))
            .trim()
            .toLowerCase();
        final newPair = statusData.pairingCode;
        final newQr = statusData.qr;

        final changed = st != _waStatus ||
            newPair != _waPaircode ||
            (newQr != null && newQr.isNotEmpty && newQr != _qrData);

        if (changed && mounted) {
          setState(() {
            _waStatus = st;
            _waPaircode = newPair;
            if (newQr != null && newQr.isNotEmpty && newQr != _qrData) {
              _qrData = newQr;
            }
          });
          _modalSetState?.call(() {});
        }

        if (_qrModalOpen && (st == 'connected' || statusData.connected == true)) {
          _closeQrModal();
        }
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusResp.error ?? 'Erro ao consultar status')),
        );
      }
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao consultar status: $e')),
      );
    } finally {
      if (mounted && !silent) setState(() => _waLoading = false);
    }
  }

  void _startStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshWhatsappStatus(silent: true);
    });
    _refreshWhatsappStatus(silent: true);
  }

  void _stopStatusPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
  }

  void _startQrCountdown() {
    _qrTimer?.cancel();
    _qrSecondsLeft = 120;
    _qrExpired = false;
    _qrTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_qrModalOpen) {
        _qrTimer?.cancel();
        return;
      }
      if (_waStatus == 'connected') {
        _qrTimer?.cancel();
        return;
      }
      if (_qrSecondsLeft <= 1) {
        _qrTimer?.cancel();
        _handleQrExpired();
      } else {
        _qrSecondsLeft--;
      }
    });
  }

  Future<void> _handleQrExpired() async {
    if (!_qrModalOpen || _waStatus == 'connected') return;
    setState(() {
      _qrExpired = true;
    });
    _modalSetState?.call(() {});
  }

  void _closeQrModal() {
    if (_qrModalOpen) {
      _qrModalOpen = false;
      _stopStatusPolling();
      _qrTimer?.cancel();
    }
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _openQrModal() async {
    _qrModalOpen = true;
    _startStatusPolling();
    _startQrCountdown();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            _modalSetState = modalSetState;
            final minutes = (_qrSecondsLeft ~/ 60).toString().padLeft(2, '0');
            final seconds = (_qrSecondsLeft % 60).toString().padLeft(2, '0');
            return AlertDialog(
              title: const Text('Conectar WhatsApp'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 240,
                    height: 240,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildQrWidget(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: const [
                            Icon(LucideIcons.loader, size: 14, color: Colors.orange),
                            SizedBox(width: 6),
                            Text('connecting', style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox.shrink(), // timer escondido
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Abra o WhatsApp > Dispositivos conectados > Conectar um dispositivo',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (_waPaircode != null) ...[
                    const SizedBox(height: 8),
                    Text('Pairing: $_waPaircode', style: const TextStyle(fontSize: 12)),
                  ],
                  if (_qrExpired) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(LucideIcons.alertTriangle, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'QR expirou. Clique em â€œGerar novo QRâ€ para tentar novamente.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (_qrExpired)
                  TextButton(
                    onPressed: _waLoading ? null : _requestNewQr,
                    child: const Text('Gerar novo QR'),
                  ),
                TextButton(
                  onPressed: () async {
                    _qrModalOpen = false;
                    _stopStatusPolling();
                    _qrTimer?.cancel();
                    Navigator.of(context, rootNavigator: true).pop();
                    await _refreshWhatsappStatus(silent: true);
                    if (mounted && _waStatus != 'connected') {
                      setState(() => _waStatus = 'disconnected');
                    }
                  },
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );

    _qrModalOpen = false;
    _modalSetState = null;
    _stopStatusPolling();
    _qrTimer?.cancel();
    _refreshWhatsappStatus(silent: true);
  }

  Widget _buildQrWidget() {
    if (_waStatus == 'connected') {
      return const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 48);
    }
    if (_qrData == null || _qrData!.isEmpty) {
      return const Text('Aguardando QR Code...');
    }
    final data = _qrData!;
    try {
      if (data.startsWith('data:image')) {
        final base64Part = data.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(bytes, fit: BoxFit.contain);
      }
      final parsed = Uri.tryParse(data);
      if (parsed != null && parsed.hasAbsolutePath) {
        return Image.network(data, fit: BoxFit.contain);
      }
      final maybeBytes = base64Decode(data);
      return Image.memory(maybeBytes, fit: BoxFit.contain);
    } catch (_) {
      return SelectableText(
        data,
        style: const TextStyle(fontSize: 12),
      );
    }
  }

  Widget _buildWhatsappStatusBadge() {
    final status = _waStatus.toLowerCase();
    Color color;
    Color bg;
    String label;

    switch (status) {
      case 'connected':
        color = Colors.green;
        bg = Colors.green.shade50;
        label = 'Conectado';
        break;
      case 'connecting':
        color = Colors.orange;
        bg = Colors.orange.shade50;
        label = 'Conectando';
        break;
      default:
        color = Colors.red;
        bg = Colors.red.shade50;
        label = 'Desconectado';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_waPaircode != null && status != 'connected') ...[
            const SizedBox(width: 12),
            Text(
              'Pairing: $_waPaircode',
              style: TextStyle(color: color.withValues(alpha: 0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleConnect() async {
    final gabinete = _gabinete ?? await ref.read(currentGabineteProvider.future);
    if (gabinete == null) return;

    setState(() => _waLoading = true);
    String? token = gabinete.token;
    debugPrint(
      '[WA] handleConnect start | gabineteId=${gabinete.id} token=${_redactToken(token)}',
    );
    final user = await ref.read(currentUserProvider.future);
    final isPrimeiroAcesso = user?.primeiroAcesso ?? _primeiroAcesso;
    if (user != null) {
      _usuarioUuid = user.uuid;
    }
    debugPrint(
      '[WA] user primeiroAcesso=${isPrimeiroAcesso} userUuid=${_usuarioUuid ?? "null"}',
    );
    if (isPrimeiroAcesso != _primeiroAcesso) {
      if (mounted) {
        setState(() => _primeiroAcesso = isPrimeiroAcesso);
      } else {
        _primeiroAcesso = isPrimeiroAcesso;
      }
    }

    try {
      if (isPrimeiroAcesso) {
        debugPrint('[WA] primeiro acesso -> criando instancia');
        final nomeInstancia = _resolveInstanceName(gabinete);
        debugPrint('[WA] nome instancia: $nomeInstancia');
        final createResp =
            await ref.read(uazapiServiceProvider).criarInstancia(nome: nomeInstancia);
        debugPrint(
          '[WA] createResp success=${createResp.isSuccess} error=${createResp.error ?? "null"}',
        );
        if (!createResp.isSuccess || createResp.data == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(createResp.error ?? 'Erro ao criar instancia')),
          );
          setState(() => _waLoading = false);
          return;
        }

        final created = createResp.data!;
        token = created.instanceToken ?? created.token;
        debugPrint(
          '[WA] instance created | instanceId=${created.instanceId ?? "null"} token=${_redactToken(token)} qr=${(created.qr?.isNotEmpty ?? false)} paircode=${created.paircode ?? "null"}',
        );
        if (token == null || token.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Token nao retornado pela API')),
          );
          setState(() => _waLoading = false);
          return;
        }

        _instanceToken = token;

        await Supabase.instance.client
            .from('gabinete')
            .update({'token': token})
            .eq('id', gabinete.id);
        if (created.instanceId != null && created.instanceId!.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('gabinete')
                .update({'instance_id_zapi': created.instanceId})
                .eq('id', gabinete.id);
          } catch (_) {}
        }
        ref.invalidate(currentGabineteProvider);

        final usuarioUuid = _usuarioUuid;
        if (usuarioUuid != null) {
          await Supabase.instance.client
              .from('usuarios')
              .update({'primeiro_acesso': false})
              .eq('uuid', usuarioUuid);
        }
        if (mounted) {
          setState(() => _primeiroAcesso = false);
        } else {
          _primeiroAcesso = false;
        }
        ref.invalidate(currentUserProvider);

        if (created.qr != null && created.qr!.isNotEmpty) {
          debugPrint('[WA] QR recebido no create -> abrindo modal');
          setState(() {
            _waStatus = 'connecting';
            _waPaircode = created.paircode;
            _qrData = created.qr;
            _qrSecondsLeft = 120;
            _qrExpired = false;
          });
          await _openQrModal();
          return;
        }
      }

      if (token == null || token.isEmpty) {
        debugPrint('[WA] token vazio apos fluxo de criacao');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token do gabinete nao encontrado.')),
        );
        return;
      }

      _instanceToken = token;
      debugPrint('[WA] conectar instancia com token=${_redactToken(token)}');
      final connectResp =
          await ref.read(uazapiServiceProvider).conectarInstancia(instanceToken: token);
      debugPrint(
        '[WA] connectResp success=${connectResp.isSuccess} error=${connectResp.error ?? "null"} qr=${(connectResp.data?.qr?.isNotEmpty ?? false)} paircode=${connectResp.data?.pairingCode ?? "null"}',
      );
      if (!connectResp.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(connectResp.error ?? 'Erro ao conectar')),
        );
        return;
      }

      setState(() {
        _waStatus = 'connecting';
        _waPaircode = connectResp.data?.pairingCode;
        _qrData = connectResp.data?.qr;
        _qrSecondsLeft = 120;
        _qrExpired = false;
      });

      await _openQrModal();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _waLoading = false);
    }
  }

  String _resolveInstanceName(Gabinete gabinete) {
    final nomeGabinete = gabinete.nome?.trim();
    if (nomeGabinete != null && nomeGabinete.isNotEmpty) {
      return nomeGabinete;
    }
    final nomeUsuario = _nomeController.text.trim();
    if (nomeUsuario.isNotEmpty) {
      return nomeUsuario;
    }
    return 'gabinete-${gabinete.id}';
  }

  String _redactToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 8) return '***';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  Future<void> _handleDisconnect() async {
    final token = _instanceToken ?? _gabinete?.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instancia para desconectar')),
      );
      return;
    }

    try {
      setState(() => _waLoading = true);
      final resp = await ref.read(uazapiServiceProvider).desconectarInstancia(token);
      if (!mounted) return;
      if (resp.isSuccess) {
        setState(() {
          _waStatus = 'disconnected';
          _waPaircode = null;
          _qrData = null;
        });
        await _refreshWhatsappStatus(silent: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instancia desconectada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resp.error ?? 'Erro ao desconectar')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desconectar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _waLoading = false);
    }
  }

  Future<void> _requestNewQr() async {
    final token = _instanceToken;
    if (token == null || token.isEmpty) return;
    setState(() {
      _waLoading = true;
      _qrExpired = false;
      _waStatus = 'connecting';
      _qrSecondsLeft = 120;
    });
    _modalSetState?.call(() {});
    final resp = await ref.read(uazapiServiceProvider).conectarInstancia(instanceToken: token);
    if (resp.isSuccess) {
      setState(() {
        _waPaircode = resp.data?.pairingCode;
        _qrData = resp.data?.qr ?? _qrData;
      });
      _startQrCountdown();
      _refreshWhatsappStatus(silent: true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp.error ?? 'Nao foi possivel gerar novo QR')),
      );
    }
    if (mounted) setState(() => _waLoading = false);
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  Future<void> _alterarFoto() async {
    final user = await ref.read(currentUserProvider.future);
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (user == null || gabinete == null) return;

    try {
      setState(() => _isUploadingFoto = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploadingFoto = false);
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() => _isUploadingFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel ler a imagem selecionada')),
        );
        return;
      }

      final storage = ref.read(storageServiceProvider);
      final upload = await storage.uploadFile(
        gabineteId: gabinete.id,
        mediaType: 'image',
        fileName: file.name,
        fileBytes: file.bytes as Uint8List,
      );

      if (!upload.isSuccess || upload.url == null) {
        setState(() => _isUploadingFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(upload.error ?? 'Erro ao enviar imagem')),
        );
        return;
      }

      final repo = ref.read(usuarioRepositoryProvider);
      await repo.updateUsuario(
        uuid: user.uuid,
        foto: upload.url,
      );

      setState(() {
        _avatarUrl = upload.url;
      });
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso!')),
        );
        _refreshWhatsappStatus(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao alterar foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFoto = false);
    }
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do sistema'),
        content: const Text('Tem certeza que deseja sair?'),
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
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      ref.read(authNotifierProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final currentGabinete = ref.watch(currentGabineteProvider);

    return MainLayout(
      title: 'Perfil',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com foto e botao de editar
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 58,
                            backgroundColor: Colors.white,
                            backgroundImage: (_avatarUrl ?? currentUser.value?.foto) != null
                                ? NetworkImage((_avatarUrl ?? currentUser.value!.foto)!)
                                : null,
                            child: (_avatarUrl ?? currentUser.value?.foto) == null
                                ? Text(
                                    currentUser.value?.nome?.substring(0, 1).toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.camera,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32),
                    // Informacoes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.value?.nome ?? 'Carregando...',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentUser.value?.cargo ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _InfoChip(
                                icon: LucideIcons.mail,
                                label: currentUser.value?.email ?? '',
                              ),
                              const SizedBox(width: 12),
                              _InfoChip(
                                icon: LucideIcons.phone,
                                label: _formatPhone(currentUser.value?.telefone ?? ''),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botao de editar
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingFoto ? null : _alterarFoto,
                          icon: _isUploadingFoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(LucideIcons.edit2),
                          label: const Text('Alterar foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (!_isEditing)
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(LucideIcons.settings2),
                            label: const Text('Editar dados'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coluna esquerda - Informacoes Pessoais
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          title: 'Informacoes Pessoais',
                          icon: LucideIcons.user,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nomeController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'Nome',
                                        prefixIcon: Icon(LucideIcons.user),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? 'Obrigatorio' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cargoController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'Cargo',
                                        prefixIcon: Icon(LucideIcons.briefcase),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _emailController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        prefixIcon: Icon(LucideIcons.mail),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) return 'Obrigatorio';
                                        if (!v.contains('@')) return 'E-mail invalido';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _telefoneController,
                                      enabled: false, // telefone e fixo (WhatsApp)
                                      decoration: const InputDecoration(
                                        labelText: 'Telefone',
                                        prefixIcon: Icon(LucideIcons.phone),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _enderecoController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Endereco do Gabinete',
                                  prefixIcon: Icon(LucideIcons.mapPin),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _prazoSolicitacoesController,
                                enabled: _isEditing,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Prazo Solicitacoes (dias)',
                                  prefixIcon: Icon(LucideIcons.clock),
                                  helperText: 'Prazo padrao para conclusao de solicitacoes',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Obrigatorio';
                                  if (int.tryParse(v) == null) return 'Deve ser um numero';
                                  return null;
                                },
                              ),
                              if (_isEditing) ...[
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _isEditing = false);
                                        _loadUserData();
                                      },
                                      child: const Text('Cancelar'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _salvarAlteracoes,
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
                                      label: const Text('Salvar Alteracoes'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Coluna direita - Seguranca e WhatsApp
                  Expanded(
                    child: Column(
                      children: [
                        _SectionCard(
                          title: 'Seguranca',
                          icon: LucideIcons.shield,
                          child: Column(
                            children: [
                              _ActionButton(
                                icon: LucideIcons.headphones,
                                label: 'Suporte',
                                description: 'Precisa de ajuda? Fale conosco',
                                color: Colors.blue,
                                onPressed: _abrirSuporteWhatsapp,
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                icon: LucideIcons.lock,
                                label: 'Alterar senha',
                                description: 'Atualize sua senha de acesso',
                                color: Colors.orange,
                                onPressed: _alterarSenha,
                              ),
                              const SizedBox(height: 12),
                              _ActionButton(
                                icon: LucideIcons.logOut,
                                label: 'Sair',
                                description: 'Encerrar sessao',
                                color: Colors.red,
                                onPressed: _sair,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SectionCard(
                          title: 'WhatsApp',
                          icon: LucideIcons.messageSquare,
                          child: Column(
                            children: [
                              _buildWhatsappStatusBadge(),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (_waStatus == 'connected')
                                    ElevatedButton.icon(
                                      onPressed: _waLoading ? null : _handleDisconnect,
                                      icon: _waLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(LucideIcons.power),
                                      label: const Text('Desconectar'),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: _waLoading ? null : _handleConnect,
                                      icon: _waLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                          )
                                        : const Icon(LucideIcons.link),
                                      label: const Text('Conectar'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_primeiroAcesso) ...[
                                _WarningBox(
                                  icon: LucideIcons.info,
                                  title: 'Primeiro acesso',
                                  description: 'O sistema vai inicializar a instancia antes de gerar o QR.',
                                ),
                                const SizedBox(height: 12),
                              ],
                              _WarningBox(
                                icon: LucideIcons.alertTriangle,
                                title: 'Uso do WhatsApp',
                                description: 'Evite envios excessivos para nao bloquear sua conta.',
                              ),
                              const SizedBox(height: 12),
                              _WarningBox(
                                icon: LucideIcons.checkCircle2,
                                title: 'Consentimento obrigatorio',
                                description: 'Envie mensagens apenas para contatos que autorizaram.',
                              ),
                              const SizedBox(height: 12),
                              _WarningBox(
                                icon: LucideIcons.alertCircle,
                                title: 'Uso consciente',
                                description: 'Evite SPAM e mantenha interacoes relevantes.',
                              ),
                            ],
                          ),
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
  }
}

/// Card de secao
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// Chip de informacao no header
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botao de acao
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Box de aviso
class _WarningBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _WarningBox({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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

/// Dialogo de alterar senha
class _AlterarSenhaDialog extends StatefulWidget {
  const _AlterarSenhaDialog();

  @override
  State<_AlterarSenhaDialog> createState() => _AlterarSenhaDialogState();
}

class _AlterarSenhaDialogState extends State<_AlterarSenhaDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _senhaAtualController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _obscureSenhaAtual = true;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmarSenha = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _alterar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _novaSenhaController.text.trim();
      final confirm = _confirmarSenhaController.text.trim();

      if (newPassword != confirm) {
        throw 'As senhas nao conferem';
      }

      final client = Supabase.instance.client;
      final res = await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (res.user == null) {
        throw 'Nao foi possivel atualizar a senha';
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar senha: $e'),
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          child: const Icon(
                            LucideIcons.lock,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Atualizar senha',
                          style: TextStyle(
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
                TextFormField(
                  controller: _senhaAtualController,
                  obscureText: _obscureSenhaAtual,
                  decoration: InputDecoration(
                    labelText: 'Senha atual',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSenhaAtual ? LucideIcons.eyeOff : LucideIcons.eye,
                      ),
                      onPressed: () => setState(() => _obscureSenhaAtual = !_obscureSenhaAtual),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _novaSenhaController,
                  obscureText: _obscureNovaSenha,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNovaSenha ? LucideIcons.eyeOff : LucideIcons.eye,
                      ),
                      onPressed: () => setState(() => _obscureNovaSenha = !_obscureNovaSenha),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obrigatorio';
                    if (v.length < 6) return 'Minimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: _obscureConfirmarSenha,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmarSenha ? LucideIcons.eyeOff : LucideIcons.eye,
                      ),
                      onPressed: () => setState(() => _obscureConfirmarSenha = !_obscureConfirmarSenha),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obrigatorio';
                    if (v != _novaSenhaController.text) return 'As senhas nao coincidem';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _alterar,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.check),
                      label: const Text('Atualizar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


