import 'package:intl/intl.dart';

import '../datasources/supabase_datasource.dart';
import '../models/dashboard_data.dart';


/// Repository for Dashboard data
class DashboardRepository {
  final SupabaseDatasource _datasource;
  
  // Cache for dashboard data
  DashboardData? _cachedData;
  int? _cachedGabineteId;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 1);

  DashboardRepository(this._datasource);

  /// Get dashboard KPIs with caching
  Future<DashboardData> getDashboardData(
    int gabineteId, {
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh &&
        _cachedData != null &&
        _cachedGabineteId == gabineteId &&
        _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedData!;
      }
    }

    // Tentar buscar KPIs via RPC (apenas contadores)
    DashboardData? rpcData;
    try {
      final result = await _datasource.rpc(
        functionName: 'get_dashboard_stats',
        params: {'p_gabinete_id': gabineteId},
      );

      if (result != null && result is Map<String, dynamic>) {
        rpcData = DashboardData.fromJson(result);
      }
    } catch (e) {
      // Se RPC não existe, calcula manualmente
    }

    // Buscar dados do gráfico semanal
    final chartData = await _getChartDataSemanal(gabineteId);

    // Buscar aniversariantes da semana
    final aniversariantes = await _getAniversariantesSemana(gabineteId);

    // Mini-listas (sempre buscar, pois o RPC não retorna listas)
    final listaAtrasadas = await _getListaAtrasadas(gabineteId);
    final listaConversasAguardando = await _getConversasAguardando(gabineteId);

    if (rpcData != null) {
      // RPC retornou contadores — complementar com listas e gráfico
      _cachedData = DashboardData(
        novasSolicitacoes: rpcData.novasSolicitacoes,
        conversasFinalizadas: rpcData.conversasFinalizadas,
        emAtendimento: rpcData.emAtendimento,
        cidadaosCadastrados: rpcData.cidadaosCadastrados,
        solicitacoesAtrasadas: rpcData.solicitacoesAtrasadas,
        solicitacoesSemanais: rpcData.solicitacoesSemanais,
        emAndamento: rpcData.emAndamento,
        concluidos: rpcData.concluidos,
        emAtraso: rpcData.emAtraso,
        totalCidadaos: rpcData.totalCidadaos,
        chartData: chartData,
        aniversariantes: aniversariantes,
        listaAtrasadas: listaAtrasadas,
        listaConversasAguardando: listaConversasAguardando,
      );
    } else {
      // Fallback: calcular contadores manualmente
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = DateFormat('yyyy-MM-dd').format(startOfWeek);

      final novas = await _getCountByStatus(gabineteId, 'todos');
      final emAndamento = await _getCountByStatus(gabineteId, 'em andamento');
      final emAnalise = await _getCountByStatus(gabineteId, 'em analise');
      final finalizadas = await _getCountByStatus(gabineteId, 'finalizado');
      final atrasadas = await _getCountAtrasadas(gabineteId);
      final semanais = await _getCountSemanal(gabineteId, startOfWeekStr);
      final totalCidadaos = await _getCidadaosCount(gabineteId);

      _cachedData = DashboardData(
        novasSolicitacoes: novas,
        conversasFinalizadas: finalizadas,
        emAtendimento: emAndamento + emAnalise,
        cidadaosCadastrados: totalCidadaos,
        solicitacoesAtrasadas: atrasadas,
        solicitacoesSemanais: semanais,
        emAndamento: emAndamento,
        concluidos: finalizadas,
        emAtraso: atrasadas,
        totalCidadaos: totalCidadaos,
        chartData: chartData,
        aniversariantes: aniversariantes,
        listaAtrasadas: listaAtrasadas,
        listaConversasAguardando: listaConversasAguardando,
      );
    }

    _cachedGabineteId = gabineteId;
    _cacheTime = DateTime.now();

    return _cachedData!;
  }

  Future<int> _getCountByStatus(int gabineteId, String status) async {
    try {
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: 'id',
        eq: {
          'gabinete': gabineteId,
          'status': status,
        },
      );
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCountAtrasadas(int gabineteId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Buscar solicitações com prazo vencido e não finalizadas
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: 'id, prazo, status',
        eq: {'gabinete': gabineteId},
      );
      
      int count = 0;
      for (final item in data) {
        final prazo = item['prazo']?.toString();
        final status = (item['status'] as String?)?.toLowerCase();
        if (prazo != null && status != 'finalizado') {
          try {
            final prazoDate = DateFormat('dd/MM/yyyy').parse(prazo);
            final prazoDay =
                DateTime(prazoDate.year, prazoDate.month, prazoDate.day);
            if (prazoDay.isBefore(today)) {
              count++;
            }
          } catch (_) {
            // Tentar outro formato
            try {
              final prazoDate = DateTime.parse(prazo);
              final prazoDay =
                  DateTime(prazoDate.year, prazoDate.month, prazoDate.day);
              if (prazoDay.isBefore(today)) {
                count++;
              }
            } catch (_) {}
          }
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCountSemanal(int gabineteId, String startOfWeek) async {
    try {
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: 'id, created_at',
        eq: {'gabinete': gabineteId},
      );
      
      final startDate = DateTime.parse(startOfWeek);
      int count = 0;
      for (final item in data) {
        final createdAt = item['created_at'] as String?;
        if (createdAt != null) {
          final createdDate = DateTime.parse(createdAt);
          if (createdDate.isAfter(startDate) || 
              createdDate.isAtSameMomentAs(startDate)) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCidadaosCount(int gabineteId) async {
    try {
      final data = await _datasource.select(
        table: 'cidadaos',
        columns: 'id',
        eq: {'gabinete': gabineteId},
      );
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<ChartDataPoint>> _getChartDataSemanal(int gabineteId) async {
    try {
      final now = DateTime.now();
      final List<ChartDataPoint> points = [];
      
      // Buscar todas as solicitações dos últimos 7 dias
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: 'id, created_at',
        eq: {'gabinete': gabineteId},
      );
      
      // Contar por dia
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final label = DateFormat('dd/MM').format(date);
        
        int count = 0;
        for (final item in data) {
          final createdAt = item['created_at'] as String?;
          if (createdAt != null) {
            final createdDate = DateTime.parse(createdAt);
            final createdDateStr = DateFormat('yyyy-MM-dd').format(createdDate);
            if (createdDateStr == dateStr) {
              count++;
            }
          }
        }
        
        points.add(ChartDataPoint(
          label: label,
          value: count.toDouble(),
          date: date,
        ));
      }
      
      return points;
    } catch (e) {
      return [];
    }
  }

  Future<List<Aniversariante>> _getAniversariantesSemana(int gabineteId) async {
    try {
      final now = DateTime.now();
      final endOfWeek = now.add(Duration(days: 7 - now.weekday));
      
      final data = await _datasource.select(
        table: 'cidadaos',
        columns: 'id, nome, data_nascimento, telefone, foto',
        eq: {'gabinete': gabineteId},
      );
      
      final List<Aniversariante> aniversariantes = [];
      for (final item in data) {
        final dataNascStr = item['data_nascimento'] as String?;
        if (dataNascStr != null) {
          try {
            final dataNasc = DateTime.parse(dataNascStr);
            // Verificar se o aniversário está na semana atual
            final anivEsteAno = DateTime(now.year, dataNasc.month, dataNasc.day);
            if (anivEsteAno.isAfter(now.subtract(const Duration(days: 1))) &&
                anivEsteAno.isBefore(endOfWeek.add(const Duration(days: 1)))) {
              aniversariantes.add(Aniversariante.fromJson(item));
            }
          } catch (_) {}
        }
      }
      
      // Ordenar por data de nascimento
      aniversariantes.sort((a, b) => 
        a.dataNascimento.month == b.dataNascimento.month
          ? a.dataNascimento.day.compareTo(b.dataNascimento.day)
          : a.dataNascimento.month.compareTo(b.dataNascimento.month)
      );
      
      return aniversariantes;
    } catch (e) {
      return [];
    }
  }

  Future<List<SolicitacaoResumo>> _getListaAtrasadas(int gabineteId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Buscar solicitações sem join (evita erro de FK ambígua)
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: 'id, titulo, prazo, status, prioridade, created_at, cidadao',
        eq: {'gabinete': gabineteId},
        orderBy: 'created_at',
        ascending: false,
      );

      // Filtrar atrasadas
      final List<Map<String, dynamic>> atrasadas = [];
      final List<int> cidadaoIds = [];

      for (final item in data) {
        final prazo = item['prazo']?.toString();
        if (prazo == null) continue;
        final status = (item['status'] as String?)?.toLowerCase();
        if (status == 'finalizado') continue;

        DateTime? prazoDate;
        try {
          prazoDate = DateFormat('dd/MM/yyyy').parse(prazo);
        } catch (_) {
          try {
            prazoDate = DateTime.parse(prazo);
          } catch (_) {}
        }

        if (prazoDate != null &&
            DateTime(prazoDate.year, prazoDate.month, prazoDate.day)
                .isBefore(today)) {
          atrasadas.add(item);
          final cidadaoId = item['cidadao'] as int?;
          if (cidadaoId != null) cidadaoIds.add(cidadaoId);
        }
        if (atrasadas.length >= 5) break;
      }

      // Buscar nomes dos cidadãos
      final nomeMap = <int, String>{};
      if (cidadaoIds.isNotEmpty) {
        try {
          final cidadaosData = await _datasource.selectIn(
            table: 'cidadaos',
            columns: 'id, nome',
            column: 'id',
            values: cidadaoIds,
          );
          for (final c in cidadaosData) {
            nomeMap[c['id'] as int] = c['nome'] as String? ?? '';
          }
        } catch (_) {
          // Se falhar ao buscar nomes, continua sem eles
        }
      }

      return atrasadas.map((item) {
        final cidadaoId = item['cidadao'] as int?;
        return SolicitacaoResumo(
          id: item['id'] as int,
          titulo: item['titulo'] as String? ?? 'Sem título',
          cidadaoNome: cidadaoId != null ? nomeMap[cidadaoId] : null,
          prioridade: item['prioridade'] as String?,
          prazo: item['prazo']?.toString(),
          status: item['status'] as String?,
          createdAt: item['created_at'] != null
              ? DateTime.tryParse(item['created_at'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ConversaAguardando>> _getConversasAguardando(
      int gabineteId) async {
    try {
      // Buscar atendimentos novos (aguardando primeira resposta)
      final data = await _datasource.select(
        table: 'atendimentos',
        columns: '*, cidadaos(nome, foto)',
        eq: {'gabinete': gabineteId, 'status': 'novo'},
        limit: 5,
        orderBy: 'created_at',
        ascending: false,
      );

      return data.map((item) {
        final cidadaos = item['cidadaos'];
        final cidadaoNome = (cidadaos is Map<String, dynamic>)
            ? cidadaos['nome'] as String?
            : null;
        final cidadaoFoto = (cidadaos is Map<String, dynamic>)
            ? cidadaos['foto'] as String?
            : null;

        return ConversaAguardando(
          id: item['id'] as int,
          cidadaoNome: cidadaoNome,
          telefone: item['telefone'] as String?,
          ultimaMensagemEm: item['created_at'] != null
              ? DateTime.tryParse(item['created_at'] as String)
              : null,
          foto: cidadaoFoto,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear cache
  void clearCache() {
    _cachedData = null;
    _cachedGabineteId = null;
    _cacheTime = null;
  }
}
