import '../datasources/supabase_datasource.dart';

/// Repository que concentra a criação de entidades iniciais do sistema
class CadastroRepository {
  final SupabaseDatasource _datasource;

  CadastroRepository(this._datasource);

  /// Cria um novo gabinete e retorna o ID recém-inserido
  Future<int> createGabinete({
    required String nome,
    String? descricao,
    String? telefone,
    String? cidade,
    String? estado,
    String? usuarioUuid,
  }) async {
    final currentUserId = _datasource.currentUserId;
    final payload = <String, dynamic>{
      'nome': nome,
      if (descricao != null && descricao.isNotEmpty) 'descricao': descricao,
      if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
      if (cidade != null && cidade.isNotEmpty) 'cidade': cidade,
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      if (usuarioUuid != null && usuarioUuid.isNotEmpty) 'usuario': usuarioUuid,
      if ((usuarioUuid == null || usuarioUuid.isEmpty) &&
          currentUserId != null) 'usuario': currentUserId,
    };

    final inserted = await _datasource.insert(
      table: 'gabinete',
      data: payload,
    );

    final idValue = inserted['id'];
    if (idValue is int) {
      return idValue;
    }

    if (idValue is String) {
      return int.parse(idValue);
    }

    throw Exception('Falha ao recuperar o ID do gabinete criado');
  }

  /// Cria um usuário do tipo vereador vinculado ao gabinete recém-criado
  Future<void> createUsuarioVereador({
    required int gabineteId,
    required String nome,
    required String email,
    required String telefone,
    String? usuarioUuid,
  }) async {
    final currentUserId = _datasource.currentUserId;
    final payload = <String, dynamic>{
      if (usuarioUuid != null && usuarioUuid.isNotEmpty) 'uuid': usuarioUuid,
      if ((usuarioUuid == null || usuarioUuid.isEmpty) &&
          currentUserId != null)
        'uuid': currentUserId,
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'gabinete': gabineteId,
      'tipo': 'vereador',
      'status': true,
      'dashboard': true,
      'solicitacoes': true,
      'cidadaos': true,
      'atividades': true,
      'transmissao': true,
      'atendimento': true,
      'acessores': true,
    };

    await _datasource.insert(
      table: 'usuarios',
      data: payload,
    );
  }
}
