import '../datasources/supabase_datasource.dart';
import '../models/gabinete.dart';

/// Repository for Gabinete data
/// This is cached aggressively since gabinete rarely changes
class GabineteRepository {
  final SupabaseDatasource _datasource;
  
  // In-memory cache
  Gabinete? _cachedGabinete;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 10);

  GabineteRepository(this._datasource);

  /// Get gabinete for current user with caching
  /// This is the most commonly needed query - cache it well
  Future<Gabinete?> getCurrentUserGabinete({bool forceRefresh = false}) async {
    final userId = _datasource.currentUserId;
    if (userId == null) return null;

    // Check cache first
    if (!forceRefresh && _cachedGabinete != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedGabinete;
      }
    }

    // Query with OR condition: user is owner OR user is in acessores array
    final data = await _datasource.select(
      table: 'gabinete',
      or: 'usuario.eq.$userId,acessores.cs.{$userId}',
      limit: 1,
    );

    if (data.isEmpty) return null;

    _cachedGabinete = Gabinete.fromJson(data.first);
    _cacheTime = DateTime.now();
    
    return _cachedGabinete;
  }

  /// Get gabinete by ID
  Future<Gabinete?> getById(int id) async {
    final data = await _datasource.selectSingle(
      table: 'gabinete',
      eq: {'id': id},
    );

    if (data == null) return null;
    return Gabinete.fromJson(data);
  }

  /// Update gabinete
  Future<Gabinete?> update({
    required int id,
    String? nome,
    String? endereco,
    String? telefone,
    String? email,
    String? logo,
  }) async {
    final updateData = <String, dynamic>{};
    if (nome != null) updateData['nome'] = nome;
    if (endereco != null) updateData['endereco'] = endereco;
    if (telefone != null) updateData['telefone'] = telefone;
    if (email != null) updateData['email'] = email;
    if (logo != null) updateData['logo'] = logo;

    if (updateData.isEmpty) return _cachedGabinete;

    final result = await _datasource.update(
      table: 'gabinete',
      data: updateData,
      eq: {'id': id},
      returnData: true,
    );

    if (result.isEmpty) return null;

    // Invalidate cache
    _cachedGabinete = null;
    _cacheTime = null;

    return Gabinete.fromJson(result.first);
  }

  /// Clear cache
  void clearCache() {
    _cachedGabinete = null;
    _cacheTime = null;
  }
}
