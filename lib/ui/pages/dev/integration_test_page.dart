import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../data/models/cidadao.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/cidadao_providers.dart';
import '../../../providers/solicitacao_providers.dart';
import '../../../providers/tarefa_providers.dart';
import '../../../providers/campanhas_whatsapp_provider.dart';
import '../../../services/notification_service.dart';
import '../../theme/app_colors.dart';

/// Página de testes de integração e população massiva de dados
class IntegrationTestPage extends ConsumerStatefulWidget {
  const IntegrationTestPage({super.key});

  @override
  ConsumerState<IntegrationTestPage> createState() => _IntegrationTestPageState();
}

class _IntegrationTestPageState extends ConsumerState<IntegrationTestPage> {
  final List<String> _logs = [];
  bool _isRunning = false;
  int _progress = 0;
  int _total = 0;
  
  // Estatísticas
  int _cidadaosAtualizados = 0;
  int _solicitacoesCriadas = 0;
  int _tarefasCriadas = 0;
  int _erros = 0;

  bool _isCreatingNotifications = false;
  bool _isGeocoding = false;
  int _geocodeSucesso = 0;
  int _geocodeFalha = 0;

  final TextEditingController _campanhaTituloController =
      TextEditingController(text: 'Campanha Gabitech (teste)');
  final TextEditingController _campanhaMensagemController =
      TextEditingController(text: 'Teste de transmissão - Gabitech');
  final TextEditingController _campanhaDataController =
      TextEditingController(text: '29/01/2026');
  final TextEditingController _campanhaHoraController =
      TextEditingController(text: '20:16');
  final List<String> _campanhaNumeros = [
    '+55 47 9901-1366',
    '+55 47 9642-9635',
    '+55 47 9758-3447',
    '5504791935950',
  ];

  void _log(String message, {bool isError = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] ${isError ? '❌' : '✅'} $message');
    });
  }

  void _logSection(String title) {
    setState(() {
      _logs.add('\n═══════════════════════════════════════');
      _logs.add('  $title');
      _logs.add('═══════════════════════════════════════\n');
    });
  }

  void _prepararCampanhaTeste() {
    final titulo = _campanhaTituloController.text.trim();
    final mensagem = _campanhaMensagemController.text.trim();
    final data = _campanhaDataController.text.trim();
    final hora = _campanhaHoraController.text.trim();
    final local = 'Gabitech';

    if (titulo.isEmpty || mensagem.isEmpty || data.isEmpty || hora.isEmpty) {
      _log('Preencha título, mensagem, data e hora.', isError: true);
      return;
    }

    _salvarCampanhaTeste(
      titulo: titulo,
      mensagem: mensagem,
      data: data,
      hora: hora,
      local: local,
    );
  }

  DateTime? _parseDataHora(String data, String hora) {
    try {
      final parts = data.split('/');
      if (parts.length != 3) return null;
      final dia = int.parse(parts[0]);
      final mes = int.parse(parts[1]);
      final ano = int.parse(parts[2]);
      final horaParts = hora.split(':');
      if (horaParts.length != 2) return null;
      final h = int.parse(horaParts[0]);
      final m = int.parse(horaParts[1]);
      return DateTime(ano, mes, dia, h, m);
    } catch (_) {
      return null;
    }
  }

  Future<void> _salvarCampanhaTeste({
    required String titulo,
    required String mensagem,
    required String data,
    required String hora,
    required String local,
  }) async {
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (gabinete == null) {
      _log('Gabinete não encontrado. Faça login primeiro.', isError: true);
      return;
    }

    final parsed = _parseDataHora(data, hora);
    final dataAgendamento = parsed == null
        ? null
        : (parsed.millisecondsSinceEpoch ~/ 1000);

    try {
      final transmissaoRepo = ref.read(transmissaoRepositoryProvider);
      final idCampanha = DateTime.now().millisecondsSinceEpoch.toString();

      await transmissaoRepo.createTransmissao(
        gabineteId: gabinete.id,
        idCampanha: idCampanha,
        titulo: titulo,
        mensagem: mensagem,
        status: 'Agendada',
        data: data,
        hora: hora,
        dataAgendamento: dataAgendamento,
        genero: 'Todos',
        perfil: const ['Todos'],
        categorias: const ['Teste'],
        bairros: const ['Todos'],
      );

      ref.read(campanhasWhatsappProvider.notifier).addTestCampaign(
            titulo: titulo,
            mensagem: mensagem,
            data: data,
            hora: hora,
            local: local,
            qtd: _campanhaNumeros.length,
            status: 'Agendada',
          );

      _logSection('CAMPANHA TESTE SALVA (transmissoes)');
      _log('Titulo: $titulo');
      _log('Mensagem: $mensagem');
      _log('Agendado para: $data $hora');
      _log('Destinatários: ${_campanhaNumeros.join(', ')}');
      _log('Observação: este teste NÃO envia mensagens.');
    } catch (e) {
      _log('Falha ao salvar campanha de teste: $e', isError: true);
    }
  }

  Future<void> _criarNotificacoesExemplo() async {
    if (_isCreatingNotifications) return;

    setState(() {
      _isCreatingNotifications = true;
    });

    try {
      _logSection('CRIANDO NOTIFICAÇÕES DE EXEMPLO');

      final gabinete = await ref.read(currentGabineteProvider.future);
      final user = await ref.read(currentUserProvider.future);

      if (gabinete == null) {
        _log('Gabinete não encontrado! Faça login primeiro.', isError: true);
        return;
      }

      final notificationService = ref.read(notificationServiceProvider);

      _log('Criando 8 notificações de exemplo...');
      await notificationService.criarNotificacoesExemplo(
        gabineteId: gabinete.id,
        usuarioId: user?.uuid,
      );

      _log('Notificações criadas com sucesso!');
      _log('Verifique o sino no topo da tela');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('8 notificações de exemplo criadas!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _log('Erro ao criar notificações: $e', isError: true);
      _erros++;
    } finally {
      setState(() {
        _isCreatingNotifications = false;
      });
    }
  }

  /// Geocodifica endereços de todos os cidadãos que não têm lat/lng
  Future<void> _geocodificarEnderecos() async {
    if (_isGeocoding) return;

    setState(() {
      _isGeocoding = true;
      _geocodeSucesso = 0;
      _geocodeFalha = 0;
      _progress = 0;
      _total = 0;
    });

    try {
      _logSection('GEOCODIFICAÇÃO DE ENDEREÇOS');

      final gabinete = await ref.read(currentGabineteProvider.future);
      if (gabinete == null) {
        _log('Gabinete não encontrado! Faça login primeiro.', isError: true);
        return;
      }

      final cidadaoRepo = ref.read(cidadaoRepositoryProvider);
      final todos = await cidadaoRepo.getByGabinete(gabinete.id, limit: 2000, forceRefresh: true);

      // Filtrar apenas cidadãos sem coordenadas que tenham algum campo de endereço
      final semCoords = todos.where((c) {
        final semLat = c.latitude == null || c.latitude!.isEmpty;
        final semLng = c.longitude == null || c.longitude!.isEmpty;
        final temEndereco = [c.rua, c.bairro, c.cidade, c.estado]
            .any((f) => f != null && f.trim().isNotEmpty);
        return (semLat || semLng) && temEndereco;
      }).toList();

      if (semCoords.isEmpty) {
        _log('Todos os cidadãos com endereço já possuem coordenadas!');
        return;
      }

      setState(() => _total = semCoords.length);
      _log('Encontrados ${semCoords.length} cidadãos sem coordenadas (de ${todos.length} total)');

      for (int i = 0; i < semCoords.length; i++) {
        final c = semCoords[i];
        setState(() => _progress = i + 1);

        try {
          final coords = await _geocodeAddress(c);

          if (coords != null) {
            await cidadaoRepo.update(
              id: c.id,
              gabineteId: gabinete.id,
              latitude: coords['lat']!,
              longitude: coords['lng']!,
            );
            _geocodeSucesso++;
            _log('${c.nome}: ${coords['lat']}, ${coords['lng']}');
          } else {
            _geocodeFalha++;
            _log('${c.nome}: endereço não encontrado (${_buildAddressQuery(c)})', isError: true);
          }
        } catch (e) {
          _geocodeFalha++;
          _log('${c.nome}: erro - $e', isError: true);
        }

        // Nominatim exige 1 req/s (política de uso)
        await Future.delayed(const Duration(milliseconds: 1100));
      }

      _logSection('RESULTADO DA GEOCODIFICAÇÃO');
      _log('Geocodificados com sucesso: $_geocodeSucesso');
      _log('Falhas: $_geocodeFalha');
      _log('Total processado: ${semCoords.length}');

      // Invalidar cache do mapa
      ref.invalidate(cidadaosMapRawProvider);
      ref.invalidate(cidadaosProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geocodificação concluída: $_geocodeSucesso OK, $_geocodeFalha falhas'),
          backgroundColor: _geocodeFalha == 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      _log('Erro geral na geocodificação: $e', isError: true);
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  /// Chama API Nominatim (OpenStreetMap) para geocodificar o endereço
  Future<Map<String, String>?> _geocodeAddress(Cidadao c) async {
    final query = _buildAddressQuery(c);
    if (query.isEmpty) return null;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json&limit=1&countrycodes=br',
    );

    final response = await http.get(url, headers: {
      'User-Agent': 'GabitechCRM/2.0 (geocoding)',
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) return null;

    final List<dynamic> results = json.decode(response.body);
    if (results.isEmpty) return null;

    final first = results[0];
    return {
      'lat': first['lat'] as String,
      'lng': first['lon'] as String,
    };
  }

  String _buildAddressQuery(Cidadao c) {
    final parts = <String>[
      if (c.rua != null && c.rua!.trim().isNotEmpty) c.rua!.trim(),
      if (c.numeroResidencia != null && c.numeroResidencia!.trim().isNotEmpty)
        c.numeroResidencia!.trim(),
      if (c.bairro != null && c.bairro!.trim().isNotEmpty) c.bairro!.trim(),
      if (c.cidade != null && c.cidade!.trim().isNotEmpty) c.cidade!.trim(),
      if (c.estado != null && c.estado!.trim().isNotEmpty) c.estado!.trim(),
    ];
    return parts.join(', ');
  }

  Future<void> _runIntegrationTests() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _logs.clear();
      _progress = 0;
      _total = 0;
      _cidadaosAtualizados = 0;
      _solicitacoesCriadas = 0;
      _tarefasCriadas = 0;
      _erros = 0;
    });

    try {
      await _testQueriesWithGabinete();
      await _populateMassiveData();
    } catch (e) {
      _log('Erro geral: $e', isError: true);
      _erros++;
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  /// Teste 1: Verifica se todas as queries estão filtrando por gabinete
  Future<void> _testQueriesWithGabinete() async {
    _logSection('TESTE DE QUERIES COM GABINETE');
    
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (gabinete == null) {
      _log('Gabinete não encontrado! Faça login primeiro.', isError: true);
      return;
    }
    
    _log('Gabinete atual: ${gabinete.nome} (ID: ${gabinete.id})');
    
    // Test 1: Cidadãos
    try {
      final cidadaoRepo = ref.read(cidadaoRepositoryProvider);
      final cidadaos = await cidadaoRepo.getByGabinete(gabinete.id);
      _log('Cidadãos carregados: ${cidadaos.length}');
      
      // Verificar se todos pertencem ao gabinete correto
      final wrongGabinete = cidadaos.where((c) => c.gabinete != gabinete.id).length;
      if (wrongGabinete > 0) {
        _log('ALERTA: $wrongGabinete cidadãos de outro gabinete!', isError: true);
        _erros++;
      } else {
        _log('Todos os cidadãos pertencem ao gabinete correto');
      }
    } catch (e) {
      _log('Erro ao carregar cidadãos: $e', isError: true);
      _erros++;
    }
    
    // Test 2: Solicitações
    try {
      final solicitacaoRepo = ref.read(solicitacaoRepositoryProvider);
      final solicitacoes = await solicitacaoRepo.getByGabinete(gabinete.id);
      _log('Solicitações carregadas: ${solicitacoes.length}');
      
      final wrongGabinete = solicitacoes.where((s) => s.gabinete != gabinete.id).length;
      if (wrongGabinete > 0) {
        _log('ALERTA: $wrongGabinete solicitações de outro gabinete!', isError: true);
        _erros++;
      } else {
        _log('Todas as solicitações pertencem ao gabinete correto');
      }
    } catch (e) {
      _log('Erro ao carregar solicitações: $e', isError: true);
      _erros++;
    }
    
    // Test 3: Categorias
    try {
      final categoriaRepo = ref.read(categoriaRepositoryProvider);
      final categorias = await categoriaRepo.getByGabinete(gabinete.id);
      _log('Categorias carregadas: ${categorias.length}');
      
      final wrongGabinete = categorias.where((c) => c.gabineteId != gabinete.id).length;
      if (wrongGabinete > 0) {
        _log('ALERTA: $wrongGabinete categorias de outro gabinete!', isError: true);
        _erros++;
      } else {
        _log('Todas as categorias pertencem ao gabinete correto');
      }
    } catch (e) {
      _log('Erro ao carregar categorias: $e', isError: true);
      _erros++;
    }
    
    // Test 4: Tarefas
    try {
      final tarefaRepo = ref.read(tarefaRepositoryProvider);
      final tarefas = await tarefaRepo.getByGabinete(gabinete.id);
      _log('Tarefas carregadas: ${tarefas.length}');
      
      final wrongGabinete = tarefas.where((t) => t.gabinete != gabinete.id).length;
      if (wrongGabinete > 0) {
        _log('ALERTA: $wrongGabinete tarefas de outro gabinete!', isError: true);
        _erros++;
      } else {
        _log('Todas as tarefas pertencem ao gabinete correto');
      }
    } catch (e) {
      _log('Erro ao carregar tarefas: $e', isError: true);
      _erros++;
    }
    
    // Test 5: Atendimentos
    try {
      final atendimentoRepo = ref.read(atendimentoRepositoryProvider);
      final atendimentos = await atendimentoRepo.getByGabinete(gabinete.id);
      _log('Atendimentos carregados: ${atendimentos.length}');
    } catch (e) {
      _log('Erro ao carregar atendimentos: $e', isError: true);
      _erros++;
    }
    
    _log('\n📊 Resultado dos testes de queries: ${_erros == 0 ? "PASSOU" : "FALHOU com $_erros erros"}');
  }

  /// Teste 2: Popula dados massivamente
  Future<void> _populateMassiveData() async {
    _logSection('POPULAÇÃO MASSIVA DE DADOS');
    
    final gabinete = await ref.read(currentGabineteProvider.future);
    if (gabinete == null) {
      _log('Gabinete não encontrado!', isError: true);
      return;
    }
    
    // 1. Carregar todos os cidadãos
    final cidadaoRepo = ref.read(cidadaoRepositoryProvider);
    final cidadaos = await cidadaoRepo.getByGabinete(gabinete.id, limit: 1000);
    
    if (cidadaos.isEmpty) {
      _log('Nenhum cidadão encontrado para processar', isError: true);
      return;
    }
    
    setState(() {
      _total = cidadaos.length;
    });
    
    _log('Encontrados ${cidadaos.length} cidadãos para processar');
    
    // 2. Carregar ou criar categorias variadas
    final categoriaRepo = ref.read(categoriaRepositoryProvider);
    var categorias = await categoriaRepo.getByGabinete(gabinete.id);

    // Categorias padrão com cores
    final categoriasConfig = [
      {'nome': 'Infraestrutura', 'cor': '#3498db'},
      {'nome': 'Saúde', 'cor': '#e74c3c'},
      {'nome': 'Educação', 'cor': '#9b59b6'},
      {'nome': 'Segurança', 'cor': '#f39c12'},
      {'nome': 'Meio Ambiente', 'cor': '#27ae60'},
      {'nome': 'Assistência Social', 'cor': '#e91e63'},
    ];

    if (categorias.isEmpty) {
      _log('Criando categorias padrão...');
      for (final config in categoriasConfig) {
        final cat = await categoriaRepo.create(
          gabineteId: gabinete.id,
          nome: config['nome']!,
          cor: config['cor'],
        );
        categorias = [...categorias, cat];
        _log('Categoria criada: ${cat.nome}');
      }
    } else {
      _log('Usando ${categorias.length} categorias existentes');
    }
    
    // 3. Processar cada cidadão
    final random = Random();
    final solicitacaoRepo = ref.read(solicitacaoRepositoryProvider);
    final tarefaRepo = ref.read(tarefaRepositoryProvider);
    
    // Dados fake para completar cadastros
    final bairros = ['Centro', 'Jardim América', 'Vila Nova', 'São José', 'Santa Maria', 'Industrial'];
    final cidades = ['São Paulo', 'Campinas', 'Santos', 'Ribeirão Preto', 'Sorocaba'];
    final ruas = ['Rua das Flores', 'Avenida Brasil', 'Rua São Paulo', 'Alameda Santos', 'Rua 15 de Novembro'];
    final generos = ['Masculino', 'Feminino'];
    
    final titulosSolicitacao = [
      'Solicitação de pavimentação',
      'Iluminação pública',
      'Poda de árvores',
      'Buraco na via',
      'Limpeza de terreno',
      'Manutenção de praça',
      'Sinalização de trânsito',
      'Coleta de lixo',
      'Esgoto a céu aberto',
      'Reparo de calçada',
    ];
    
    final descricoesSolicitacao = [
      'Necessita de atenção urgente devido às condições precárias.',
      'Moradores reclamam há meses sobre este problema.',
      'Situação afeta a mobilidade dos pedestres.',
      'Problema recorrente que precisa de solução definitiva.',
      'Questão de segurança pública que requer providências.',
    ];
    
    final atividadesTitulos = [
      'Realizar vistoria no local',
      'Entrar em contato com secretaria responsável',
      'Agendar reunião com moradores',
      'Solicitar orçamento',
      'Acompanhar execução do serviço',
    ];
    
    final prioridades = ['Baixa', 'Média', 'Alta'];
    final statusList = ['todos', 'em analise', 'em andamento', 'aguardando usuario'];
    
    for (int i = 0; i < cidadaos.length; i++) {
      final cidadao = cidadaos[i];
      
      setState(() {
        _progress = i + 1;
      });
      
      try {
        // 3.1. Completar cadastro do cidadão se estiver incompleto
        final needsUpdate = cidadao.bairro == null || 
                           cidadao.cidade == null || 
                           cidadao.rua == null ||
                           cidadao.email == null ||
                           cidadao.genero == null;
        
        if (needsUpdate) {
          final updateData = <String, dynamic>{};
          
          if (cidadao.bairro == null) {
            updateData['bairro'] = bairros[random.nextInt(bairros.length)];
          }
          if (cidadao.cidade == null) {
            updateData['cidade'] = cidades[random.nextInt(cidades.length)];
          }
          if (cidadao.rua == null) {
            updateData['rua'] = ruas[random.nextInt(ruas.length)];
          }
          if (cidadao.estado == null) {
            updateData['estado'] = 'SP';
          }
          if (cidadao.cep == null) {
            updateData['cep'] = '${10000 + random.nextInt(89999)}-${100 + random.nextInt(899)}';
          }
          if (cidadao.numeroResidencia == null) {
            updateData['numero_residencia'] = '${random.nextInt(999) + 1}';
          }
          if (cidadao.email == null && cidadao.nome != null) {
            final emailName = cidadao.nome!.toLowerCase()
                .replaceAll(' ', '.')
                .replaceAll(RegExp(r'[^a-z0-9.]'), '');
            updateData['email'] = '$emailName@email.com';
          }
          if (cidadao.genero == null) {
            updateData['genero'] = generos[random.nextInt(generos.length)];
          }
          if (cidadao.dataNascimento == null) {
            // Gerar data de nascimento entre 18 e 80 anos atrás
            final anos = 18 + random.nextInt(62);
            final dataNasc = DateTime.now().subtract(Duration(days: anos * 365 + random.nextInt(365)));
            updateData['data_nascimento'] = dataNasc.toIso8601String().substring(0, 10);
          }
          
          if (updateData.isNotEmpty) {
            await cidadaoRepo.update(
              id: cidadao.id,
              gabineteId: gabinete.id,
              email: updateData['email'],
              bairro: updateData['bairro'],
              cidade: updateData['cidade'],
              rua: updateData['rua'],
              estado: updateData['estado'],
              cep: updateData['cep'],
              numeroResidencia: updateData['numero_residencia'],
              genero: updateData['genero'],
              dataNascimento: updateData['data_nascimento'],
            );
            _cidadaosAtualizados++;
          }
        }
        
        // 3.2. Verificar se cidadão já tem solicitação
        final solicitacoesExistentes = await solicitacaoRepo.getByCidadao(
          cidadao.id, 
          gabineteId: gabinete.id,
        );
        
        if (solicitacoesExistentes.isEmpty) {
          // 3.3. Criar solicitação
          final titulo = titulosSolicitacao[random.nextInt(titulosSolicitacao.length)];
          final descricao = descricoesSolicitacao[random.nextInt(descricoesSolicitacao.length)];
          final prioridade = prioridades[random.nextInt(prioridades.length)];
          final status = statusList[random.nextInt(statusList.length)];
          
          // Prazo entre 7 e 60 dias
          final prazo = DateTime.now().add(Duration(days: 7 + random.nextInt(53)));
          final prazoStr = '${prazo.day.toString().padLeft(2, '0')}/${prazo.month.toString().padLeft(2, '0')}/${prazo.year}';
          
          // Selecionar categoria aleatória
          final categoriaEscolhida = categorias[random.nextInt(categorias.length)];

          final solicitacao = await solicitacaoRepo.create(
            gabineteId: gabinete.id,
            cidadaoId: cidadao.id,
            titulo: titulo,
            descricao: '$descricao\n\nCidadão: ${cidadao.nome ?? "N/A"}\nLocal: ${cidadao.bairro ?? "N/A"}',
            prioridade: prioridade,
            categoriaId: categoriaEscolhida.id,
            categoria: categoriaEscolhida.nome,
            status: status,
            prazo: prazoStr,
          );
          
          _solicitacoesCriadas++;
          
          // 3.4. Criar 2-3 atividades para a solicitação
          final numAtividades = 2 + random.nextInt(2);
          for (int j = 0; j < numAtividades; j++) {
            final atividadeTitulo = atividadesTitulos[random.nextInt(atividadesTitulos.length)];
            
            await tarefaRepo.create(
              gabineteId: gabinete.id,
              solicitacaoId: solicitacao.id,
              titulo: atividadeTitulo,
              descricao: 'Atividade referente à solicitação: ${solicitacao.titulo}',
            );
            _tarefasCriadas++;
          }
        }
        
        if ((i + 1) % 10 == 0) {
          _log('Processados ${i + 1}/${cidadaos.length} cidadãos...');
        }
        
      } catch (e) {
        _log('Erro ao processar cidadão ${cidadao.nome}: $e', isError: true);
        _erros++;
      }
      
      // Pequena pausa para não sobrecarregar a API
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _logSection('RESULTADO FINAL');
    _log('Cidadãos atualizados: $_cidadaosAtualizados');
    _log('Solicitações criadas: $_solicitacoesCriadas');
    _log('Atividades criadas: $_tarefasCriadas');
    _log('Erros: $_erros');
    _log('\n🎉 Processo concluído!');
    
    // Invalidar providers para atualizar a UI
    ref.invalidate(cidadaosProvider);
    ref.invalidate(solicitacoesKanbanProvider);
    ref.invalidate(solicitacoesListProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Teste de Integração'),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Testes de Transmissões (mock)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cria um rascunho de campanha para a tela de transmissões (sem envio real).',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _campanhaTituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _campanhaMensagemController,
                    decoration: const InputDecoration(
                      labelText: 'Mensagem',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _campanhaDataController,
                          decoration: const InputDecoration(
                            labelText: 'Data',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _campanhaHoraController,
                          decoration: const InputDecoration(
                            labelText: 'Hora',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Destinatários: ${_campanhaNumeros.join(', ')}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _prepararCampanhaTeste,
                    child: const Text('Preparar campanha teste (mock)'),
                  ),
                  const SizedBox(height: 24),
            // Header com botão
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teste de Integração e População de Dados',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Verifica queries, completa cadastros e gera solicitações com atividades',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isGeocoding ? null : _geocodificarEnderecos,
                          icon: _isGeocoding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.location_on),
                          label: Text(_isGeocoding ? 'Geocodificando...' : 'Geocodificar Endereços'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isCreatingNotifications ? null : _criarNotificacoesExemplo,
                          icon: _isCreatingNotifications
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.notifications_active),
                          label: Text(_isCreatingNotifications ? 'Criando...' : 'Criar Notificações'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isRunning ? null : _runIntegrationTests,
                          icon: _isRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(_isRunning ? 'Executando...' : 'Executar Testes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Progress bar
                    if ((_isRunning || _isGeocoding) && _total > 0) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _progress / _total,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$_progress / $_total',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Estatísticas geocodificação
            if (_geocodeSucesso > 0 || _geocodeFalha > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    _buildStatCard('Geocodificados', _geocodeSucesso, Icons.location_on, Colors.teal),
                    const SizedBox(width: 16),
                    _buildStatCard('Falhas Geocode', _geocodeFalha, Icons.location_off, Colors.red),
                  ],
                ),
              ),

            // Estatísticas testes
            if (_cidadaosAtualizados > 0 || _solicitacoesCriadas > 0 || _tarefasCriadas > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    _buildStatCard('Cidadãos Atualizados', _cidadaosAtualizados, Icons.person, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Solicitações Criadas', _solicitacoesCriadas, Icons.assignment, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Atividades Criadas', _tarefasCriadas, Icons.task, Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatCard('Erros', _erros, Icons.error, Colors.red),
                  ],
                ),
              ),
            
            // Logs
            Expanded(
              child: Card(
                color: const Color(0xFF1E1E1E),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.terminal,
                            color: Colors.green[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Console de Logs',
                            style: TextStyle(
                              color: Colors.green[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _logs.clear()),
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Limpar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    Expanded(
                      child: _logs.isEmpty
                          ? Center(
                              child: Text(
                                'Clique em "Executar Testes" para iniciar',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                final isError = log.contains('❌');
                                final isSection = log.contains('═══');
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      color: isError 
                                          ? Colors.red[400]
                                          : isSection 
                                              ? Colors.cyan[300]
                                              : Colors.green[300],
                                      fontWeight: isSection ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
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

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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
