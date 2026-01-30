import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cidadao.dart';
import 'core_providers.dart';
import 'package:latlong2/latlong.dart';

/// Provider for cidadÃ£os list with pagination
final cidadaosProvider = FutureProvider.autoDispose
    .family<List<Cidadao>, CidadaosParams>((ref, params) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repository = ref.watch(cidadaoRepositoryProvider);
  return repository.getByGabinete(
    gabinete.id,
    limit: params.limit,
    offset: params.offset,
    searchTerm: params.searchTerm,
    status: params.status,
    forceRefresh: params.forceRefresh,
  );
});

/// Provider for single cidadÃ£o
final cidadaoProvider = FutureProvider.autoDispose
    .family<Cidadao?, int>((ref, id) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  final repository = ref.watch(cidadaoRepositoryProvider);
  return repository.getById(id, gabineteId: gabinete?.id);
});

/// State notifier for cidadÃ£o operations
class CidadaoNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CidadaoNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<Cidadao?> create({
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
    state = const AsyncValue.loading();
    
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      if (gabinete == null) {
        state = AsyncValue.error('Gabinete nÃ£o encontrado', StackTrace.current);
        return null;
      }

      final repository = _ref.read(cidadaoRepositoryProvider);
      final cidadao = await repository.create(
        gabineteId: gabinete.id,
        nome: nome,
        email: email,
        telefone: telefone,
        dataNascimento: dataNascimento,
        genero: genero,
        perfil: perfil,
        bairro: bairro,
        cep: cep,
        rua: rua,
        cidade: cidade,
        estado: estado,
        numeroResidencia: numeroResidencia,
        complemento: complemento,
        pontoReferencia: pontoReferencia,
        latitude: latitude,
        longitude: longitude,
      );

      // Invalidate the list provider
      _ref.invalidate(cidadaosProvider);
      
      state = const AsyncValue.data(null);
      return cidadao;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> update({
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
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final gabinete = await _ref.read(currentGabineteProvider.future);
      final repository = _ref.read(cidadaoRepositoryProvider);
      await repository.update(
        id: id,
        gabineteId: gabinete?.id,
        nome: nome,
        email: email,
        telefone: telefone,
        foto: foto,
        perfil: perfil,
        bairro: bairro,
        cep: cep,
        rua: rua,
        cidade: cidade,
        estado: estado,
        numeroResidencia: numeroResidencia,
        genero: genero,
        dataNascimento: dataNascimento,
        complemento: complemento,
        pontoReferencia: pontoReferencia,
        latitude: latitude,
        longitude: longitude,
        status: 'cadastrado',
      );

      // Invalidate providers
      _ref.invalidate(cidadaosProvider);
      _ref.invalidate(cidadaoProvider(id));
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final cidadaoNotifierProvider =
    StateNotifierProvider<CidadaoNotifier, AsyncValue<void>>((ref) {
  return CidadaoNotifier(ref);
});

/// Parameters for cidadÃ£os provider
class CidadaosParams {
  final int? limit;
  final int? offset;
  final String? searchTerm;
  final String? status;
  final bool forceRefresh;

  const CidadaosParams({
    this.limit,
    this.offset,
    this.searchTerm,
    this.status,
    this.forceRefresh = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CidadaosParams &&
        other.limit == limit &&
        other.offset == offset &&
        other.searchTerm == searchTerm &&
        other.status == status &&
        other.forceRefresh == forceRefresh;
  }

  @override
  int get hashCode => Object.hash(limit, offset, searchTerm, status, forceRefresh);
}

/// --- Mapa de cidadÃ£os ---

final cidadaosMapSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

final cidadaosMapOnlyGeocodedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// Rua selecionada para filtro no mapa (null = todas)
final cidadaosMapStreetProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Busca todos os cidadÃ£os do gabinete uma Ãºnica vez (sem dependÃªncia de busca)
final cidadaosMapRawProvider =
    FutureProvider.autoDispose<List<Cidadao>>((ref) async {
  final gabinete = await ref.watch(currentGabineteProvider.future);
  if (gabinete == null) return [];

  final repository = ref.watch(cidadaoRepositoryProvider);
  return repository.getByGabinete(gabinete.id, limit: 2000);
});

/// Filtra localmente â€” nunca dispara nova requisiÃ§Ã£o Ã  API
final cidadaosMapProvider = Provider.autoDispose<List<Cidadao>>((ref) {
  final raw = ref.watch(cidadaosMapRawProvider).valueOrNull ?? [];
  final search = ref.watch(cidadaosMapSearchProvider).toLowerCase();
  final streetFilter = ref.watch(cidadaosMapStreetProvider);

  return raw.where((c) {
    // SEMPRE filtra por coordenadas - apenas cidadãos com lat/long cadastrados
    final hasCoords = _parseLatLng(c) != null;
    if (!hasCoords) return false;

    if (streetFilter != null && streetFilter.trim().isNotEmpty) {
      final rua = (c.rua ?? '').toLowerCase();
      if (!rua.contains(streetFilter.toLowerCase())) return false;
    }

    if (search.isEmpty) return true;
    final normalizedQuery = _normalize(search);
    return [
      c.nome,
      c.rua,
      c.bairro,
      c.cidade,
      c.estado,
      c.telefone,
    ].any((field) => _normalize(field ?? '').contains(normalizedQuery));
  }).toList();
});

LatLng? _parseLatLng(Cidadao c) {
  final lat = double.tryParse(c.latitude ?? '');
  final lng = double.tryParse(c.longitude ?? '');
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

String _normalize(String input) {
  // remove acentos e normaliza para comparação case-insensitive
  final lower = input.toLowerCase();
  const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const without =    'aaaaaeeeeiiiiooooouuuucn';
  var result = lower;
  for (var i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], without[i]);
  }
  return result;
}
