import '../datasources/supabase_datasource.dart';
import '../models/usuario.dart';

/// Repository for Usuario data
/// Handles data access with optional caching
class UsuarioRepository {
  final SupabaseDatasource _datasource;
  
  // In-memory cache
  Usuario? _cachedCurrentUser;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  UsuarioRepository(this._datasource);

  /// Get current logged user with caching
  Future<Usuario?> getCurrentUser({bool forceRefresh = false}) async {
    final userId = _datasource.currentUserId;
    if (userId == null) return null;

    // Check cache
    if (!forceRefresh && _cachedCurrentUser != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedCurrentUser;
      }
    }

    final data = await _datasource.selectSingle(
      table: 'usuarios',
      eq: {'uuid': userId},
    );

    if (data == null) return null;

    _cachedCurrentUser = Usuario.fromJson(data);
    _cacheTime = DateTime.now();
    
    return _cachedCurrentUser;
  }

  /// Get user by UUID
  Future<Usuario?> getByUuid(String uuid) async {
    final data = await _datasource.selectSingle(
      table: 'usuarios',
      eq: {'uuid': uuid},
    );

    if (data == null) return null;
    return Usuario.fromJson(data);
  }

  /// Get all assessors for a gabinete
  Future<List<Usuario>> getAcessoresByGabinete(int gabineteId) async {
    final data = await _datasource.select(
      table: 'usuarios',
      eq: {'gabinete': gabineteId, 'tipo': 'acessor'},
    );

    return data.map((json) => Usuario.fromJson(json)).toList();
  }

  /// Create a new assessor
  Future<Usuario?> createAcessor({
    required String email,
    required String password,
    required String nome,
    required String telefone,
    required String cargo,
    required int gabineteId,
    bool dashboard = false,
    bool solicitacoes = false,
    bool cidadaos = false,
    bool atividades = false,
    bool transmissoes = false,
    bool mensagens = false,
    bool acessores = false,
  }) async {
    // Evita perder a sessão atual ao criar um novo usuário via signUp,
    // guardando a sessão e restaurando depois.
    final previousSession = _datasource.client.auth.currentSession;

    try {
      // Create auth user with Supabase
      final authResponse = await _datasource.client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) return null;

      // Create usuario record
      final usuarioData = {
        'uuid': authResponse.user!.id,
        'email': email,
        'nome': nome,
        'telefone': telefone,
        'cargo': cargo,
        'gabinete': gabineteId,
        'tipo': 'acessor',
        'status': true,
        'dashboard': dashboard,
        'solicitacoes': solicitacoes,
        'cidadaos': cidadaos,
        'atividades': atividades,
        'transmissao': transmissoes,
        'atendimento': mensagens,
        'acessores': acessores,
      };

      final result = await _datasource.insert(
        table: 'usuarios',
        data: usuarioData,
      );

      // Vincular o novo assessor ao gabinete (coluna acessores do gabinete)
      try {
        final gabData = await _datasource.selectSingle(
          table: 'gabinete',
          columns: 'acessores',
          eq: {'id': gabineteId},
        );
        if (gabData != null) {
          final List<dynamic> current =
              (gabData['acessores'] as List<dynamic>? ?? []).toList();
          final uuid = authResponse.user!.id;
          if (!current.contains(uuid)) {
            current.add(uuid);
            await _datasource.update(
              table: 'gabinete',
              data: {'acessores': current},
              eq: {'id': gabineteId},
            );
          }
        }
      } catch (_) {
        // não bloqueia o fluxo se falhar; apenas não adiciona na lista
      }

      return Usuario.fromJson(result);
    } catch (e) {
      rethrow;
    } finally {
      // Restaurar sessão anterior (evita trocar para o novo usuário recém-criado).
      if (previousSession?.refreshToken != null) {
        await _datasource.client.auth.setSession(
          previousSession!.refreshToken!,
        );
      }
    }
  }

  /// Update assessor permissions
  Future<Usuario?> updateAcessorPermissions({
    required String uuid,
    String? nome,
    String? telefone,
    String? cargo,
    bool? status,
    bool? dashboard,
    bool? solicitacoes,
    bool? cidadaos,
    bool? atividades,
    bool? transmissoes,
    bool? mensagens,
    bool? acessores,
  }) async {
    final updateData = <String, dynamic>{};
    if (nome != null) updateData['nome'] = nome;
    if (telefone != null) updateData['telefone'] = telefone;
    if (cargo != null) updateData['cargo'] = cargo;
    if (status != null) updateData['status'] = status;
    if (dashboard != null) updateData['dashboard'] = dashboard;
    if (solicitacoes != null) updateData['solicitacoes'] = solicitacoes;
    if (cidadaos != null) updateData['cidadaos'] = cidadaos;
    if (atividades != null) updateData['atividades'] = atividades;
    if (transmissoes != null) updateData['transmissao'] = transmissoes;
    if (mensagens != null) updateData['atendimento'] = mensagens;
    if (acessores != null) updateData['acessores'] = acessores;

    if (updateData.isEmpty) return null;

    final result = await _datasource.update(
      table: 'usuarios',
      data: updateData,
      eq: {'uuid': uuid},
      returnData: true,
    );

    if (result.isEmpty) return null;
    return Usuario.fromJson(result.first);
  }

  /// Delete assessor
  Future<bool> deleteAcessor(String uuid) async {
    // Segurança: evitar apagar usuário de auth diretamente pelo cliente.
    // Fazemos soft-delete na tabela app e removemos acessos; remoção de auth
    // deve ser feita via função protegida (service role) fora do app cliente.
    try {
      await _datasource.update(
        table: 'usuarios',
        data: {
          'status': false,
          'dashboard': false,
          'solicitacoes': false,
          'cidadaos': false,
          'atividades': false,
          'transmissao': false,
          'atendimento': false,
          'acessores': false,
          'tipo': 'revogado',
        },
        eq: {'uuid': uuid},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update user profile
  Future<Usuario?> updateProfile({
    required String uuid,
    String? nome,
    String? avatar,
    String? telefone,
  }) async {
    final updateData = <String, dynamic>{};
    if (nome != null) updateData['nome'] = nome;
    if (avatar != null) updateData['avatar'] = avatar;
    if (telefone != null) updateData['telefone'] = telefone;

    if (updateData.isEmpty) return _cachedCurrentUser;

    final result = await _datasource.update(
      table: 'usuarios',
      data: updateData,
      eq: {'uuid': uuid},
      returnData: true,
    );

    if (result.isEmpty) return null;

    // Invalidate cache
    _cachedCurrentUser = null;
    _cacheTime = null;

    return Usuario.fromJson(result.first);
  }

  /// Clear cache (call on logout or when data changes)
  void clearCache() {
    _cachedCurrentUser = null;
    _cacheTime = null;
  }
}
