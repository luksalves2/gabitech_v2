import 'package:intl/intl.dart';

import '../datasources/supabase_datasource.dart';
import '../models/solicitacao.dart';

/// Repository for Solicitacao data
class SolicitacaoRepository {
  final SupabaseDatasource _datasource;

  SolicitacaoRepository(this._datasource);

  /// Enrich raw solicitacao JSON list with cidadao data fetched separately
  Future<List<Solicitacao>> _enrichWithCidadaoData(
      List<Map<String, dynamic>> data,
      {int? gabineteId}) async {
    // Collect unique cidadao IDs
    final cidadaoIds = <int>{};
    for (final item in data) {
      final cidadaoId = item['cidadao'] as int?;
      if (cidadaoId != null) cidadaoIds.add(cidadaoId);
    }

    // Batch fetch cidadao data
    final cidadaoMap = <int, Map<String, dynamic>>{};
    if (cidadaoIds.isNotEmpty) {
      try {
        List<Map<String, dynamic>> cidadaosData;

        if (gabineteId != null) {
          // Restringe a consulta ao gabinete atual e filtra pelos IDs necessários
          cidadaosData = await _datasource.select(
            table: 'cidadaos',
            columns: 'id, nome, foto, perfil, gabinete',
            eq: {'gabinete': gabineteId},
          );
          cidadaosData = cidadaosData
              .where((c) => cidadaoIds.contains(c['id'] as int? ?? -1))
              .toList();
        } else {
          cidadaosData = await _datasource.selectIn(
            table: 'cidadaos',
            columns: 'id, nome, foto, perfil, gabinete',
            column: 'id',
            values: cidadaoIds.toList(),
          );
        }

        for (final c in cidadaosData) {
          cidadaoMap[c['id'] as int] = c;
        }
      } catch (_) {
        // If cidadao fetch fails, continue without names
      }
    }

    // Inject cidadao data into each JSON and parse
    return data.map((json) {
      final cidadaoId = json['cidadao'] as int?;
      if (cidadaoId != null && cidadaoMap.containsKey(cidadaoId)) {
        json['cidadaos'] = cidadaoMap[cidadaoId];
      }
      return Solicitacao.fromJson(json);
    }).toList();
  }

  /// Detecta prazos vencidos e marca status como "em atraso" (DB + memória).
  Future<List<Map<String, dynamic>>> _applyOverdueStatus(
      List<Map<String, dynamic>> data) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final idsToUpdate = <int>[];

    for (final item in data) {
      final status = (item['status'] as String?)?.toLowerCase();
      if (status == 'finalizado' || status == 'em atraso') continue;

      final prazoStr = item['prazo']?.toString();
      if (prazoStr == null) continue;

      DateTime? prazoDate;
      try {
        prazoDate = DateFormat('dd/MM/yyyy').parse(prazoStr);
      } catch (_) {
        try {
          prazoDate = DateTime.parse(prazoStr);
        } catch (_) {}
      }

      if (prazoDate != null) {
        final prazoDay = DateTime(prazoDate.year, prazoDate.month, prazoDate.day);
        if (prazoDay.isBefore(todayDate)) {
          item['status'] = 'em atraso';
          final id = item['id'] as int?;
          if (id != null) idsToUpdate.add(id);
        }
      }
    }

    if (idsToUpdate.isNotEmpty) {
      // Persist best-effort; ignore failures to keep UI responsive
      await Future.wait(idsToUpdate.map((id) {
        return _datasource.update(
          table: 'solicitacoes',
          data: {'status': 'em atraso'},
          eq: {'id': id},
        );
      }));
    }

    return data;
  }

  /// Get all solicitacoes for Kanban view (grouped by status string)
  Future<Map<String, List<Solicitacao>>> getByGabineteGroupedByStatus(
    int gabineteId, {
    int? categoriaId,
    String? searchTerm,
  }) async {
    try {
      final data = await _datasource.select(
        table: 'solicitacoes',
        columns: '*',
        eq: {
          'gabinete': gabineteId,
          if (categoriaId != null) 'categoria_id': categoriaId,
        },
        orderBy: 'created_at',
        ascending: false,
      );

      final dataWithStatus = await _applyOverdueStatus(data);
      var solicitacoes =
          await _enrichWithCidadaoData(dataWithStatus, gabineteId: gabineteId);

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final term = searchTerm.toLowerCase();
        solicitacoes = solicitacoes.where((s) {
          return s.titulo?.toLowerCase().contains(term) == true ||
              s.descricao?.toLowerCase().contains(term) == true ||
              s.nomeAcessor?.toLowerCase().contains(term) == true;
        }).toList();
      }

      // Group by status string
      final grouped = <String, List<Solicitacao>>{
        'todos': [],
        'em analise': [],
        'em andamento': [],
        'aguardando usuario': [],
        'finalizado': [],
        'em atraso': [],
        'programado': [],
      };

      for (final sol in solicitacoes) {
        final status = sol.status?.toLowerCase() ?? 'todos';
        if (grouped.containsKey(status)) {
          grouped[status]!.add(sol);
        } else {
          grouped['todos']!.add(sol);
        }
      }

      return grouped;
    } catch (e) {
      // Retornar mapa vazio em caso de erro
      return {
        'todos': [],
        'em analise': [],
        'em andamento': [],
        'aguardando usuario': [],
        'finalizado': [],
        'em atraso': [],
        'programado': [],
      };
    }
  }

  /// Get all solicitacoes as flat list (for list view)
  Future<List<Solicitacao>> getByGabinete(
    int gabineteId, {
    int? categoriaId,
    String? searchTerm,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final eq = <String, dynamic>{
      'gabinete': gabineteId,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (status != null) 'status': status,
    };

    final data = await _datasource.select(
      table: 'solicitacoes',
      columns: '*',
      eq: eq,
      limit: limit,
      offset: offset,
      orderBy: 'created_at',
      ascending: false,
    );

    final dataWithStatus = await _applyOverdueStatus(data);
    var solicitacoes =
        await _enrichWithCidadaoData(dataWithStatus, gabineteId: gabineteId);

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final term = searchTerm.toLowerCase();
      solicitacoes = solicitacoes.where((s) {
        return s.titulo?.toLowerCase().contains(term) == true ||
            s.descricao?.toLowerCase().contains(term) == true;
      }).toList();
    }

    return solicitacoes;
  }

  /// Get solicitacao by ID with all related data
  Future<Solicitacao?> getById(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.selectSingle(
      table: 'solicitacoes',
      columns: '*',
      eq: eq,
    );

    if (data == null) return null;

    // Fetch cidadao data separately
    final cidadaoId = data['cidadao'] as int?;
    if (cidadaoId != null) {
      try {
        final cidadaoData = await _datasource.selectSingle(
          table: 'cidadaos',
          columns: 'id, nome, foto, perfil',
          eq: {'id': cidadaoId},
        );
        if (cidadaoData != null) {
          data['cidadaos'] = cidadaoData;
        }
      } catch (_) {}
    }

    return Solicitacao.fromJson(data);
  }

  /// Get solicitacoes for a specific cidadao
  Future<List<Solicitacao>> getByCidadao(int cidadaoId, {int? gabineteId}) async {
    final eq = <String, dynamic>{'cidadao': cidadaoId};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.select(
      table: 'solicitacoes',
      eq: eq,
      orderBy: 'created_at',
      ascending: false,
    );

    return _enrichWithCidadaoData(data, gabineteId: gabineteId);
  }

  /// Create new solicitacao
  Future<Solicitacao> create({
    required int gabineteId,
    required int cidadaoId,
    required String titulo,
    String? descricao,
    String? resumo,
    String? prioridade,
    int? categoriaId,
    String? categoria,
    String? prazo,
    String? acessor,
    String? nomeAcessor,
    String status = 'todos',
  }) async {
    final data = await _datasource.insert(
      table: 'solicitacoes',
      data: {
        'gabinete': gabineteId,
        'cidadao': cidadaoId,
        'titulo': titulo,
        'status': status,
        if (descricao != null) 'descricao': descricao,
        if (resumo != null) 'resumo': resumo,
        if (prioridade != null) 'prioridade': prioridade,
        if (categoriaId != null) 'categoria_id': categoriaId,
        if (categoria != null) 'categoria': categoria,
        if (prazo != null) 'prazo': prazo,
        if (acessor != null) 'acessor': acessor,
        if (nomeAcessor != null) 'nome_acessor': nomeAcessor,
      },
    );

    return Solicitacao.fromJson(data);
  }

  /// Update solicitacao
  Future<Solicitacao> update({
    required int id,
    String? titulo,
    String? descricao,
    String? resumo,
    String? status,
    String? prioridade,
    int? categoriaId,
    String? categoria,
    String? prazo,
    String? acessor,
    String? nomeAcessor,
    int? gabineteId,
  }) async {
    final updates = <String, dynamic>{};

    if (titulo != null) updates['titulo'] = titulo;
    if (descricao != null) updates['descricao'] = descricao;
    if (resumo != null) updates['resumo'] = resumo;
    if (status != null) updates['status'] = status;
    if (prioridade != null) updates['prioridade'] = prioridade;
    if (categoriaId != null) updates['categoria_id'] = categoriaId;
    if (categoria != null) updates['categoria'] = categoria;
    if (prazo != null) updates['prazo'] = prazo;
    if (acessor != null) updates['acessor'] = acessor;
    if (nomeAcessor != null) updates['nome_acessor'] = nomeAcessor;

    final data = await _datasource.update(
      table: 'solicitacoes',
      data: updates,
      eq: {
        'id': id,
        if (gabineteId != null) 'gabinete': gabineteId,
      },
      returnData: true,
    );

    return Solicitacao.fromJson(data.first);
  }

  /// Update only the status of a solicitacao
  Future<Solicitacao> updateStatus({
    required int id,
    required String status,
    int? gabineteId,
  }) async {
    final data = await _datasource.update(
      table: 'solicitacoes',
      data: {'status': status},
      eq: {
        'id': id,
        if (gabineteId != null) 'gabinete': gabineteId,
      },
      returnData: true,
    );

    return Solicitacao.fromJson(data.first);
  }

  /// Delete solicitacao
  Future<void> delete(int id, {int? gabineteId}) async {
    await _datasource.delete(
      table: 'solicitacoes',
      eq: {
        'id': id,
        if (gabineteId != null) 'gabinete': gabineteId,
      },
    );
  }
}
