import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/models/cidadao.dart';
import '../../../providers/cidadao_providers.dart';
import '../../layouts/main_layout.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/cached_avatar.dart';

class CidadaosMapPage extends ConsumerStatefulWidget {
  const CidadaosMapPage({super.key});

  @override
  ConsumerState<CidadaosMapPage> createState() => _CidadaosMapPageState();
}

class _CidadaosMapPageState extends ConsumerState<CidadaosMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMenuProvider.notifier).state = 'cidadaos-map';
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    EasyDebounce.debounce(
      'map-search',
      const Duration(milliseconds: 400),
      () {
        if (mounted) {
          ref.read(cidadaosMapSearchProvider.notifier).state =
              _searchController.text;
        }
      },
    );
  }

  @override
  void dispose() {
    EasyDebounce.cancel('map-search');
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Observa o raw provider apenas para loading/error inicial
    final rawAsync = ref.watch(cidadaosMapRawProvider);

    return MainLayout(
      title: 'Geolocalização',
      child: rawAsync.when(
        data: (_) => _MapContent(
          mapController: _mapController,
          searchController: _searchController,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro ao carregar cidadÃ£os: $e'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(cidadaosMapRawProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapContent extends ConsumerWidget {
  const _MapContent({
    required this.mapController,
    required this.searchController,
  });

  final MapController mapController;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lê a lista filtrada (Provider síncrono - nunca causa loading)
    final cidadaos = ref.watch(cidadaosMapProvider);
    final street = ref.watch(cidadaosMapStreetProvider);
    final raw = ref.watch(cidadaosMapRawProvider).valueOrNull ?? [];
    final streetOptions = _streetOptions(raw);
    final markers = _buildMarkers(context, cidadaos);

    final center = _defaultCenter(cidadaos);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final map = _buildMap(markers, center: center);
        final list = _buildList(context, ref, cidadaos);

        if (isWide) {
          return Row(
            children: [
              SizedBox(
                width: 420,
                child: Column(
                  children: [
                    _SearchBar(
                      controller: searchController,
                      onClear: () => searchController.clear(),
                    ),
                    const SizedBox(height: 12),
                    _FiltersRow(
                      streets: streetOptions,
                      selectedStreet: street,
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: list),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: map,
                  ),
                ),
              ),
            ],
          );
        }

        // Mobile / tablet: mapa em tela cheia + bottom sheet da lista
        return Stack(
          children: [
            Positioned.fill(child: map),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SearchBar(
                      controller: searchController,
                      onClear: () => searchController.clear(),
                      elevation: 6,
                    ),
                    const SizedBox(height: 12),
                    _FiltersRow(
                      streets: streetOptions,
                      selectedStreet: street,
                    ),
                  ],
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.18,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Expanded(
                        child: _buildList(
                          context,
                          ref,
                          cidadaos,
                          controller: scrollController,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  LatLng _defaultCenter(List<Cidadao> cidadaos) {
    if (cidadaos.isNotEmpty) {
      final first = _parseLatLng(cidadaos.first);
      if (first != null) return first;
    }
    return const LatLng(-26.3044, -48.8464); // Joinville-SC
  }

  FlutterMap _buildMap(
    List<Marker> markers, {
    required LatLng center,
  }) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileProvider: CancellableNetworkTileProvider(),
          userAgentPackageName: 'com.gabitech.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  List<Marker> _buildMarkers(BuildContext context, List<Cidadao> cidadaos) {
    return cidadaos
        .map((c) {
          final latLng = _parseLatLng(c);
          return latLng == null ? null : MapEntry(c, latLng);
        })
        .whereType<MapEntry<Cidadao, LatLng>>()
        .map((entry) {
          final cidadao = entry.key;
          final position = entry.value;
          return Marker(
            point: position,
            width: 46,
            height: 46,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _showBottomCard(context, cidadao, position),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CachedAvatar(
                  imageUrl: cidadao.foto,
                  name: cidadao.nome,
                  radius: 20,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          );
        })
        .toList();
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<Cidadao> cidadaos, {
    ScrollController? controller,
  }) {
    if (cidadaos.isEmpty) {
      return const Center(
        child: Text('Nenhum cidadÃ£o geolocalizado para este gabinete.'),
      );
    }

    return ListView.separated(
      controller: controller ?? ScrollController(),
      itemCount: cidadaos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = cidadaos[index];
        final latLng = _parseLatLng(c);

        return ListTile(
          leading: CachedAvatar(
            imageUrl: c.foto,
            name: c.nome,
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          ),
          title: Text(c.nome ?? 'CidadÃ£o'),
          subtitle: Text(
            _shortAddress(c),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(LucideIcons.mapPin),
          onTap: latLng == null
              ? null
              : () => mapController.move(latLng, 15),
        );
      },
    );
  }

  void _showBottomCard(BuildContext context, Cidadao c, LatLng position) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CachedAvatar(
                    imageUrl: c.foto,
                    name: c.nome,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nome ?? 'CidadÃ£o',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(_shortAddress(c)),
                        if (c.telefone != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(LucideIcons.phone, size: 16),
                              const SizedBox(width: 6),
                              Text(_formatPhone(c.telefone!)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(LucideIcons.mapPin, size: 16),
                    label: Text('${position.latitude.toStringAsFixed(4)}, '
                        '${position.longitude.toStringAsFixed(4)}'),
                  ),
                  if (c.perfil != null && c.perfil!.isNotEmpty)
                    Chip(
                      avatar: const Icon(LucideIcons.user, size: 16),
                      label: Text(c.perfil!),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortAddress(Cidadao c) {
    final parts = <String>[
      if (c.rua != null && c.rua!.isNotEmpty) c.rua!,
      if (c.bairro != null && c.bairro!.isNotEmpty) c.bairro!,
      if (c.cidade != null && c.cidade!.isNotEmpty) c.cidade!,
      if (c.estado != null && c.estado!.isNotEmpty) c.estado!,
    ];
    return parts.isEmpty ? 'EndereÃ§o nÃ£o informado' : parts.join(', ');
  }

  List<String> _streetOptions(List<Cidadao> cidadaos) {
    final set = <String>{};
    for (final c in cidadaos) {
      final rua = c.rua?.trim();
      if (rua != null && rua.isNotEmpty) set.add(rua);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onClear,
    this.elevation = 2,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Material(
          elevation: elevation,
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(LucideIcons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: onClear,
                    ),
              hintText: 'Buscar por nome, rua, bairro ou cidade',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        );
      },
    );
  }
}

class _FiltersRow extends ConsumerWidget {
  const _FiltersRow({
    required this.streets,
    required this.selectedStreet,
  });

  final List<String> streets;
  final String? selectedStreet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cidadaosMapProvider).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mensagem explicativa
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.info, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exibindo apenas cidadãos com coordenadas (latitude/longitude) cadastradas',
                  style: TextStyle(fontSize: 12, color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            value: selectedStreet,
            decoration: InputDecoration(
              labelText: 'Rua',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Todas'),
              ),
              ...streets.map(
                (r) => DropdownMenuItem<String>(
                  value: r,
                  child: Text(r),
                ),
              ),
            ],
            onChanged: (value) {
              ref.read(cidadaosMapStreetProvider.notifier).state =
                  (value == null || value.isEmpty) ? null : value;
            },
          ),
        ),
            Text('$count encontrados'),
          ],
        ),
      ],
    );
  }
}

String _formatPhone(String raw) {
  // Remove sufixo @s.whatsapp.net
  var phone = raw.replaceAll(RegExp(r'@.*$'), '');
  // Manter apenas dÃ­gitos
  phone = phone.replaceAll(RegExp(r'[^\d]'), '');
  // Remover cÃ³digo do paÃ­s 55
  if (phone.startsWith('55') && phone.length >= 12) {
    phone = phone.substring(2);
  }
  // Formato: (XX) XXXXX-XXXX ou (XX) XXXX-XXXX
  if (phone.length == 11) {
    return '(${phone.substring(0, 2)}) ${phone.substring(2, 7)}-${phone.substring(7)}';
  } else if (phone.length == 10) {
    return '(${phone.substring(0, 2)}) ${phone.substring(2, 6)}-${phone.substring(6)}';
  }
  return phone;
}

LatLng? _parseLatLng(Cidadao c) {
  final lat = double.tryParse(c.latitude ?? '');
  final lng = double.tryParse(c.longitude ?? '');
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}
