import '../datasources/supabase_datasource.dart';
import '../models/cidadao.dart';

/// Repository for Cidadao data
class CidadaoRepository {
  final SupabaseDatasource _datasource;
  
  // In-memory cache for cidadaos list (per gabinete)
  final Map<int, List<Cidadao>> _cidadaosCache = {};
  final Map<int, DateTime> _cacheTimes = {};
  static const _cacheDuration = Duration(minutes: 2);

  CidadaoRepository(this._datasource);

  /// Get cidadaos for a gabinete with caching
  Future<List<Cidadao>> getByGabinete(
    int gabineteId, {
    int? limit,
    int? offset,
    String? searchTerm,
    String? status,
    bool forceRefresh = false,
  }) async {
    // For search queries or status filters, don't use cache
    if ((searchTerm != null && searchTerm.isNotEmpty) || status != null) {
      return _fetchCidadaos(
        gabineteId,
        limit: limit,
        offset: offset,
        searchTerm: searchTerm,
        status: status,
      );
    }

    // Check cache for paginated results (only first page)
    if (!forceRefresh && offset == null || offset == 0) {
      final cached = _cidadaosCache[gabineteId];
      final cacheTime = _cacheTimes[gabineteId];
      
      if (cached != null && cacheTime != null) {
        if (DateTime.now().difference(cacheTime) < _cacheDuration) {
          return cached;
        }
      }
    }

    final result = await _fetchCidadaos(
      gabineteId,
      limit: limit,
      offset: offset,
    );

    // Cache first page only
    if (offset == null || offset == 0) {
      _cidadaosCache[gabineteId] = result;
      _cacheTimes[gabineteId] = DateTime.now();
    }

    return result;
  }

  Future<List<Cidadao>> _fetchCidadaos(
    int gabineteId, {
    int? limit,
    int? offset,
    String? searchTerm,
    String? status,
  }) async {
    try {
      // Build search filter if needed
      String? orFilter;
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final term = searchTerm.toLowerCase();
        orFilter = 'nome.ilike.%$term%,telefone.ilike.%$term%,email.ilike.%$term%';
      }
      
      // Build eq filters
      final eqFilters = <String, dynamic>{'gabinete': gabineteId};
      if (status != null && status.isNotEmpty) {
        eqFilters['status'] = status;
      }

      final data = await _datasource.select(
        table: 'cidadaos',
        eq: eqFilters,
        or: orFilter,
        limit: limit ?? 50,
        offset: offset,
        orderBy: 'nome',
        ascending: true,
      );

      return data.map((json) => Cidadao.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get cidadao by ID
  Future<Cidadao?> getById(int id, {int? gabineteId}) async {
    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }
    
    final data = await _datasource.selectSingle(
      table: 'cidadaos',
      eq: eq,
    );

    if (data == null) return null;
    return Cidadao.fromJson(data);
  }

  /// Get multiple cidadaos by IDs (for batch loading)
  /// This is the solution for N+1 problem
  Future<Map<int, Cidadao>> getByIds(List<int> ids, {int? gabineteId}) async {
    if (ids.isEmpty) return {};

    // Use eq filter with gabinete if provided
    final eq = <String, dynamic>{};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }

    final data = await _datasource.select(
      table: 'cidadaos',
      columns: '*',
      eq: eq.isNotEmpty ? eq : null,
    );

    // Filter manually since we don't have in() exposed
    final cidadaos = data
        .where((json) => ids.contains(json['id'] as int))
        .map((json) => Cidadao.fromJson(json))
        .toList();

    return {for (final c in cidadaos) c.id: c};
  }

  /// Create new cidadao
  Future<Cidadao> create({
    required int gabineteId,
    required String nome,
    String? email,
    String? telefone,
    String? dataNascimento,
    String? genero,
    String? perfil,
    String? bairro,
    String? cep,
    String? rua,
    String? cidade,
    String? estado,
    String? numeroResidencia,
    String? complemento,
    String? pontoReferencia,
    String? latitude,
    String? longitude,
  }) async {
    final data = await _datasource.insert(
      table: 'cidadaos',
      data: {
        'gabinete': gabineteId,
        'nome': nome,
        if (email != null) 'email': email,
        if (telefone != null) 'telefone': telefone,
        if (dataNascimento != null) 'data_nascimento': dataNascimento,
        if (genero != null) 'genero': genero,
        if (perfil != null) 'perfil': perfil,
        if (bairro != null) 'bairro': bairro,
        if (cep != null) 'cep': cep,
        if (rua != null) 'rua': rua,
        if (cidade != null) 'cidade': cidade,
        if (estado != null) 'estado': estado,
        if (numeroResidencia != null) 'numero_residencia': numeroResidencia,
        if (complemento != null) 'complemento': complemento,
        if (pontoReferencia != null) 'ponto_referencia': pontoReferencia,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );

    // Invalidate cache for this gabinete
    _cidadaosCache.remove(gabineteId);
    _cacheTimes.remove(gabineteId);

    return Cidadao.fromJson(data);
  }

  /// Update cidadao
  Future<Cidadao?> update({
    required int id,
    String? nome,
    String? email,
    String? telefone,
    String? foto,
    String? perfil,
    String? bairro,
    String? cep,
    String? rua,
    String? cidade,
    String? estado,
    String? numeroResidencia,
    String? genero,
    String? dataNascimento,
    String? complemento,
    String? pontoReferencia,
    String? latitude,
    String? longitude,
    String? status,
    int? gabineteId,
  }) async {
    final updateData = <String, dynamic>{};
    if (nome != null) updateData['nome'] = nome;
    if (email != null) updateData['email'] = email;
    if (telefone != null) updateData['telefone'] = telefone;
    if (foto != null) updateData['foto'] = foto;
    if (perfil != null) updateData['perfil'] = perfil;
    if (bairro != null) updateData['bairro'] = bairro;
    if (cep != null) updateData['cep'] = cep;
    if (rua != null) updateData['rua'] = rua;
    if (cidade != null) updateData['cidade'] = cidade;
    if (estado != null) updateData['estado'] = estado;
    if (numeroResidencia != null) updateData['numero_residencia'] = numeroResidencia;
    if (genero != null) updateData['genero'] = genero;
    if (dataNascimento != null) updateData['data_nascimento'] = dataNascimento;
    if (complemento != null) updateData['complemento'] = complemento;
    if (pontoReferencia != null) updateData['ponto_referencia'] = pontoReferencia;
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;
    if (status != null) updateData['status'] = status;

    if (updateData.isEmpty) return null;

    final eq = <String, dynamic>{'id': id};
    if (gabineteId != null) {
      eq['gabinete'] = gabineteId;
    }

    final result = await _datasource.update(
      table: 'cidadaos',
      data: updateData,
      eq: eq,
      returnData: true,
    );

    if (result.isEmpty) return null;

    // Invalidate all caches since we don't know the gabinete
    _cidadaosCache.clear();
    _cacheTimes.clear();

    return Cidadao.fromJson(result.first);
  }

  /// Clear cache
  void clearCache() {
    _cidadaosCache.clear();
    _cacheTimes.clear();
  }
}
