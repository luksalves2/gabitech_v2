import 'dart:developer' as developer;

import '../datasources/supabase_datasource.dart';
import '../models/atendimento.dart';

/// Repository for Atendimento (chat sessions) data
class AtendimentoRepository {
  final SupabaseDatasource _datasource;

  AtendimentoRepository(this._datasource);

  /// Get all atendimentos for a gabinete with cidadão info
  Future<List<Atendimento>> getByGabinete(
    int gabineteId, {
    String? status,
    int? limit,
    int? offset,
    String? searchTerm,
  }) async {
    try {
      final eq = <String, dynamic>{'gabinete': gabineteId};
      if (status != null) {
        eq['status'] = status;
      }

      // Buscar telefone do gabinete para comparação (com tratamento de erro)
      String? telefoneGabinete;
      try {
        developer.log(
          'getByGabinete -> buscando telefone do gabinete $gabineteId',
          name: 'AtendimentoRepository',
        );
        final gabineteData = await _datasource.selectSingle(
          table: 'gabinetes',
          columns: 'telefone',
          eq: {'id': gabineteId},
        );
        telefoneGabinete = gabineteData?['telefone'] as String?;
        developer.log(
          'getByGabinete <- telefone gabinete: ${telefoneGabinete ?? "null"}',
          name: 'AtendimentoRepository',
        );
      } catch (e, st) {
        developer.log(
          'getByGabinete ERRO telefone gabinete $gabineteId: $e',
          name: 'AtendimentoRepository',
          error: e,
          stackTrace: st,
        );
        // Se falhar, continua sem o telefone do gabinete
        telefoneGabinete = null;
      }

      // Get atendimentos with cidadão join
      final data = await _datasource.select(
        table: 'atendimentos',
        columns: '*, cidadaos(*)',
        eq: eq,
        limit: limit ?? 50,
        offset: offset,
        orderBy: 'created_at',
        ascending: false,
      );

      // Se não há atendimentos, retorna lista vazia
      if (data.isEmpty) return [];

      // Buscar última mensagem de cada atendimento
      final atendimentoIds = data.map((json) => json['id'] as int).toList();
      final lastMessages = await _getLastMessages(gabineteId, atendimentoIds, telefoneGabinete);

      final atendimentos = data.map((json) {
        final id = json['id'] as int;
        final lastMsg = lastMessages[id];
        final modifiableJson = Map<String, dynamic>.from(json);
        if (lastMsg != null) {
          modifiableJson['last_message'] = lastMsg['mensagem'];
          modifiableJson['last_message_at'] = lastMsg['created_at'];
          modifiableJson['last_message_type'] = lastMsg['tipo'];
                  }
        return Atendimento.fromJson(modifiableJson);
      }).toList();

      // Filter by search term if provided
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final term = searchTerm.toLowerCase();
        return atendimentos.where((a) {
          return a.displayName.toLowerCase().contains(term) || a.telefone.contains(term);
        }).toList();
      }

      return atendimentos;
    } catch (e, st) {
      developer.log(
        'getByGabinete ERRO geral: $e',
        name: 'AtendimentoRepository',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }  /// Busca a Ãºltima mensagem de cada atendimento
  Future<Map<int, Map<String, dynamic>>> _getLastMessages(
    int gabineteId, 
    List<int> atendimentoIds,
    String? telefoneGabinete,
  ) async {
    if (atendimentoIds.isEmpty) return {};

    try {
      // Buscar mensagens ordenadas por data, pegar as mais recentes de cada atendimento
      final data = await _datasource.client
          .from('mensagens')
          .select('atendimento, mensagem, created_at, tipo, telefone')
          .eq('gabinete', gabineteId)
          .inFilter('atendimento', atendimentoIds)
          .order('created_at', ascending: false);
      
      // Agrupar por atendimento, mantendo apenas a Ãºltima (primeira no resultado)
      final Map<int, Map<String, dynamic>> result = {};
      for (final msg in data) {
        final atendimentoId = msg['atendimento'] as int?;
        if (atendimentoId != null && !result.containsKey(atendimentoId)) {
          // Criar cÃ³pia modificÃ¡vel
          final msgCopy = Map<String, dynamic>.from(msg);
          
          // Determinar se a mensagem foi enviada pelo gabinete
          // telefone da mensagem = quem enviou
          // Se telefone da mensagem == telefone do gabinete â†’ gabinete enviou
          final telefoneMensagem = (msgCopy['telefone'] as String?)?.replaceAll('@s.whatsapp.net', '') ?? '';
          final telefoneGabLimpo = telefoneGabinete?.replaceAll('@s.whatsapp.net', '') ?? '';
          
          final isFromMe = telefoneGabLimpo.isNotEmpty && 
              telefoneMensagem.isNotEmpty && 
              telefoneMensagem == telefoneGabLimpo;
          
                    result[atendimentoId] = msgCopy;
        }
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  /// Get active atendimentos (em atendimento)
  Future<List<Atendimento>> getActive(int gabineteId) async {
    return getByGabinete(gabineteId, status: 'em atendimento');
  }

  /// Get atendimento by ID
  Future<Atendimento?> getById(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.selectSingle(
      table: 'atendimentos',
      columns: '*, cidadaos(*)',
      eq: eq,
    );

    if (data == null) return null;
    return Atendimento.fromJson(data);
  }

  /// Get atendimento by phone
  Future<Atendimento?> getByPhone(int gabineteId, String telefone) async {
    final data = await _datasource.selectSingle(
      table: 'atendimentos',
      columns: '*, cidadaos(*)',
      eq: {'gabinete': gabineteId, 'telefone': telefone},
    );

    if (data == null) return null;
    return Atendimento.fromJson(data);
  }

  /// Create a new atendimento
  Future<Atendimento?> create({
    required int gabineteId,
    required String telefone,
    int? cidadaoId,
    String status = 'em atendimento',
  }) async {
    final data = await _datasource.insert(
      table: 'atendimentos',
      data: {
        'gabinete': gabineteId,
        'telefone': telefone,
        'cidadao': cidadaoId,
        'status': status,
        'autorizado': true,
      },
    );

    return Atendimento.fromJson(data);
  }

  /// Update atendimento status
  Future<void> updateStatus(int id, String status) async {
    await _datasource.update(
      table: 'atendimentos',
      eq: {'id': id},
      data: {'status': status},
    );
  }

  /// Update autorizacao (lock/unlock)
  Future<void> updateAutorizado(int id, bool autorizado, {int? gabineteId}) async {
    await _datasource.update(
      table: 'atendimentos',
      eq: {
        'id': id,
        if (gabineteId != null) 'gabinete': gabineteId,
      },
      data: {'autorizado': autorizado},
    );
  }

  /// Link cidadÃ£o to atendimento
  Future<void> linkCidadao(int atendimentoId, int cidadaoId) async {
    await _datasource.update(
      table: 'atendimentos',
      eq: {'id': atendimentoId},
      data: {'cidadao': cidadaoId},
    );
  }

  /// End atendimento
  Future<void> encerrar(int id) async {
    await updateStatus(id, 'finalizado');
  }

  /// Update resumo/observações gerais do atendimento
  Future<void> updateObsGerais(int id, String? obsGerais, {int? gabineteId}) async {
    developer.log(
      'updateObsGerais -> id=$id, gabineteId=${gabineteId ?? "null"}, obs=${obsGerais ?? "null"}',
      name: 'AtendimentoRepository',
    );

    final result = await _datasource.update(
      table: 'atendimentos',
      eq: {
        'id': id,
        if (gabineteId != null) 'gabinete': gabineteId,
      },
      data: {'obs_gerais': obsGerais},
      returnData: true,
    );

    developer.log(
      'updateObsGerais <- rows=${result.length} payload=$result',
      name: 'AtendimentoRepository',
    );
  }

  /// Stream atendimentos for realtime updates
  Stream<List<Atendimento>> watchAtendimentos(int gabineteId) {
    return _datasource.client
        .from('atendimentos')
        .stream(primaryKey: ['id'])
        .eq('gabinete', gabineteId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Atendimento.fromJson(json)).toList());
  }
}





