import 'dart:developer' as developer;

import '../datasources/supabase_datasource.dart';
import '../models/mensagem.dart';

/// Repository for Mensagem data
class MensagemRepository {
  final SupabaseDatasource _datasource;

  MensagemRepository(this._datasource);

  String _normalizePhone(String? phone) {
    if (phone == null) return '';
    var value = phone.replaceAll('@s.whatsapp.net', '');
    value = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (value.startsWith('55') && value.length > 11) {
      value = value.substring(2);
    }
    return value;
  }

  Future<String?> _getTelefoneGabinete(int gabineteId) async {
    try {
      final data = await _datasource.selectSingle(
        table: 'gabinetes',
        columns: 'telefone',
        eq: {'id': gabineteId},
      );
      return data?['telefone'] as String?;
    } catch (e, st) {
      developer.log(
        'Erro ao buscar telefone do gabinete $gabineteId: $e',
        name: 'MensagemRepository',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  List<Mensagem> _mapMensagens(
    List<Map<String, dynamic>> data, {
    String? telefoneGabinete,
  }) {
    final telefoneGabNormalizado = _normalizePhone(telefoneGabinete);

    return data.map((json) {
      final msg = Mensagem.fromJson(json);
      if (telefoneGabNormalizado.isEmpty) {
        return msg;
      }
      final telefoneMsg = _normalizePhone(msg.telefone);
      final isFromMe =
          telefoneMsg.isNotEmpty && telefoneMsg == telefoneGabNormalizado;
      return msg.copyWith(isFromMe: isFromMe);
    }).toList();
  }

  /// Get messages for an atendimento
  Future<List<Mensagem>> getByAtendimento(
    int atendimentoId, {
    int? gabineteId,
    String? telefoneGabinete,
    int? limit,
    int? offset,
  }) async {
    final eq = <String, dynamic>{'atendimento': atendimentoId};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    String? telefoneParaComparar = telefoneGabinete;
    if ((telefoneParaComparar == null || telefoneParaComparar.isEmpty) &&
        gabineteId != null) {
      telefoneParaComparar = await _getTelefoneGabinete(gabineteId);
    }

    final data = await _datasource.select(
      table: 'mensagens',
      eq: eq,
      limit: limit ?? 100,
      offset: offset,
      orderBy: 'created_at',
      ascending: true,
    );

    return _mapMensagens(data, telefoneGabinete: telefoneParaComparar);
  }

  /// Get messages by phone number
  Future<List<Mensagem>> getByPhone(
    int gabineteId,
    String telefone, {
    String? telefoneGabinete,
    int? limit,
    int? offset,
  }) async {
    String? telefoneParaComparar = telefoneGabinete;
    if (telefoneParaComparar == null || telefoneParaComparar.isEmpty) {
      telefoneParaComparar = await _getTelefoneGabinete(gabineteId);
    }
    final data = await _datasource.select(
      table: 'mensagens',
      eq: {'gabinete': gabineteId, 'telefone': telefone},
      limit: limit ?? 100,
      offset: offset,
      orderBy: 'created_at',
      ascending: true,
    );

    return _mapMensagens(data, telefoneGabinete: telefoneParaComparar);
  }

  /// Get latest messages for each conversation (for list)
  Future<List<Map<String, dynamic>>> getConversationsPreview(int gabineteId) async {
    // This would ideally be a custom RPC function on Supabase
    // For now, get recent messages grouped by atendimento
    final data = await _datasource.select(
      table: 'mensagens',
      eq: {'gabinete': gabineteId},
      limit: 500,
      orderBy: 'created_at',
      ascending: false,
    );

    // Group by atendimento and get latest
    final Map<int, Map<String, dynamic>> grouped = {};
    for (final msg in data) {
      final atendimentoId = msg['atendimento'] as int?;
      if (atendimentoId != null && !grouped.containsKey(atendimentoId)) {
        grouped[atendimentoId] = msg;
      }
    }

    return grouped.values.toList();
  }

  /// Send a message (create locally, webhook handles actual sending)
  Future<Mensagem?> sendMessage({
    required int gabineteId,
    required int atendimentoId,
    required String telefone,
    required String mensagem,
    required String tipo,
    int? cidadaoId,
    String? mediaUrl,
  }) async {
    final data = await _datasource.insert(
      table: 'mensagens',
      data: {
        'gabinete': gabineteId,
        'atendimento': atendimentoId,
        'telefone': telefone,
        'mensagem': mensagem,
        'tipo': tipo,
        'cidadao': cidadaoId,
        if (mediaUrl != null) 'media_url': mediaUrl,
      },
    );

    // Mensagem enviada pelo gabinete
    return Mensagem.fromJson(data).copyWith(isFromMe: true);
  }

  /// Stream messages for realtime updates
  Stream<List<Mensagem>> watchMessages(
    int atendimentoId, {
    int? gabineteId,
    String? telefoneGabinete,
  }) {
    Future<String?> telefoneFuture;
    if (telefoneGabinete != null && telefoneGabinete.isNotEmpty) {
      telefoneFuture = Future.value(telefoneGabinete);
    } else if (gabineteId != null) {
      telefoneFuture = _getTelefoneGabinete(gabineteId);
    } else {
      telefoneFuture = Future.value(null);
    }

    return telefoneFuture.asStream().asyncExpand((tel) {
      final telefoneNormalizado = _normalizePhone(tel);

      return _datasource.client
          .from('mensagens')
          .stream(primaryKey: ['id'])
          .eq('atendimento', atendimentoId)
          .order('created_at', ascending: true)
          .map((data) {
        if (telefoneNormalizado.isEmpty) {
          return data.map((json) => Mensagem.fromJson(json)).toList();
        }

        return data.map((json) {
          final msg = Mensagem.fromJson(json);
          final telefoneMsg = _normalizePhone(msg.telefone);
          final isFromMe =
              telefoneMsg.isNotEmpty && telefoneMsg == telefoneNormalizado;
          return msg.copyWith(isFromMe: isFromMe);
        }).toList();
      });
    });
  }

  /// Get message by ID
  Future<Mensagem?> getById(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.selectSingle(
      table: 'mensagens',
      eq: eq,
    );

    if (data == null) return null;
    return Mensagem.fromJson(data);
  }
}
