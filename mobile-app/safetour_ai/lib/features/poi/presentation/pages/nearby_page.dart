import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/poi_entity.dart';
import '../bloc/poi_bloc.dart';
import '../bloc/poi_event.dart';
import '../bloc/poi_state.dart';
import '../../../map/presentation/pages/map_page.dart';

class NearbyPage extends StatelessWidget {
  const NearbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PoiBloc>()..add(const LoadNearbyPOIs(type: 'hotel')),
      child: const _NearbyView(),
    );
  }
}

class _NearbyView extends StatefulWidget {
  const _NearbyView();

  @override
  State<_NearbyView> createState() => _NearbyViewState();
}

class _NearbyViewState extends State<_NearbyView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  static const List<Map<String, dynamic>> _categories = [
    {
      'type': 'hotel',
      'label': 'Hotels & Lodges',
      'icon': Icons.hotel_rounded,
      'color': Color(0xFF4F46E5),
      'subtitle': 'Lodges, guest houses & homestays',
    },
    {
      'type': 'tourist_spot',
      'label': 'Places to Visit',
      'icon': Icons.attractions_rounded,
      'color': Color(0xFFEC4899),
      'subtitle': 'Temples, forts, viewpoints & parks',
    },
    {
      'type': 'restaurant',
      'label': 'Food & Cafes',
      'icon': Icons.restaurant_rounded,
      'color': Color(0xFFF59E0B),
      'subtitle': 'Local eateries & dining',
    },
    {
      'type': 'hospital',
      'label': 'Hospitals',
      'icon': Icons.local_hospital_rounded,
      'color': Color(0xFFEF4444),
      'subtitle': 'Emergency & clinics',
    },
    {
      'type': 'pharmacy',
      'label': 'Pharmacies',
      'icon': Icons.medication_rounded,
      'color': Color(0xFF14B8A6),
      'subtitle': 'Medical shops & chemists',
    },
    {
      'type': 'police',
      'label': 'Police Stations',
      'icon': Icons.local_police_rounded,
      'color': Color(0xFF3B82F6),
      'subtitle': 'Safety & emergency desks',
    },
    {
      'type': 'atm',
      'label': 'ATMs & Banks',
      'icon': Icons.atm_rounded,
      'color': Color(0xFF10B981),
      'subtitle': 'Cash & currency',
    },
    {
      'type': 'petrol_pump',
      'label': 'Fuel Stations',
      'icon': Icons.local_gas_station_rounded,
      'color': Color(0xFFF97316),
      'subtitle': 'Petrol, diesel & EV charging',
    },
    {
      'type': 'bus_stop',
      'label': 'Bus & Transit',
      'icon': Icons.directions_bus_rounded,
      'color': Color(0xFF06B6D4),
      'subtitle': 'Bus stands & transit stops',
    },
    {
      'type': 'railway_station',
      'label': 'Railway Stations',
      'icon': Icons.train_rounded,
      'color': Color(0xFF6366F1),
      'subtitle': 'Train halts & junctions',
    },
    {
      'type': 'shopping',
      'label': 'Shopping',
      'icon': Icons.shopping_bag_rounded,
      'color': Color(0xFFE11D48),
      'subtitle': 'Malls & retail shops',
    },
    {
      'type': 'supermarket',
      'label': 'Supermarkets',
      'icon': Icons.shopping_cart_rounded,
      'color': Color(0xFF84CC16),
      'subtitle': 'Groceries & provisions',
    },
    {
      'type': 'college',
      'label': 'Colleges & Universities',
      'icon': Icons.school_rounded,
      'color': Color(0xFF7C3AED),
      'subtitle': 'Higher education campuses',
    },
    {
      'type': 'toilet',
      'label': 'Public Restrooms',
      'icon': Icons.wc_rounded,
      'color': Color(0xFF8B5CF6),
      'subtitle': 'Hygiene facilities',
    },
  ];

  static const List<int> _radii = [1000, 3000, 5000, 8000];

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Nearby Places',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Small hotels, lodges, heritage & sightseeing',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh live data',
            onPressed: () {
              final state = context.read<PoiBloc>().state;
              context.read<PoiBloc>().add(LoadNearbyPOIs(
                    type: state.selectedType,
                    radiusMeters: state.selectedRadius,
                    forceRefresh: true,
                  ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Box
          _buildSearchBox(context),

          // Primary Category Selector Chips
          _buildCategoryFilter(context),

          // Subtype Filter Chips (Lodges, Guest houses, Temples, etc.)
          _buildSubtypeFilter(context),

          // Radius Filter Bar
          _buildRadiusFilter(context),

          // Results List
          Expanded(
            child: BlocBuilder<PoiBloc, PoiState>(
              builder: (context, state) {
                if (state is PoiLoading) {
                  return _LoadingStateWithTimeout(
                    onRetry: () {
                      final s = context.read<PoiBloc>().state;
                      context.read<PoiBloc>().add(LoadNearbyPOIs(
                            type: s.selectedType,
                            radiusMeters: s.selectedRadius,
                            subType: s.selectedSubType,
                            forceRefresh: true,
                          ));
                    },
                  );
                } else if (state is PoiError) {
                  return _buildErrorState(context, state.message);
                } else if (state is PoiLoaded) {
                  final list = state.filteredPois;
                  if (list.isEmpty) {
                    return _buildEmptyState(
                      context,
                      state.selectedType,
                      state.selectedRadius,
                      state.searchQuery,
                      state.selectedSubType,
                    );
                  }
                  return _buildPoiList(context, list);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            _searchDebounceTimer?.cancel();
            _searchDebounceTimer = Timer(const Duration(milliseconds: 280), () {
              if (mounted) {
                context.read<PoiBloc>().add(UpdateSearchQuery(val));
              }
            });
          },
          onSubmitted: (query) {
            _searchDebounceTimer?.cancel();
            if (query.trim().isNotEmpty) {
              final state = context.read<PoiBloc>().state;
              context.read<PoiBloc>().add(LoadNearbyPOIs(
                    type: state.selectedType,
                    radiusMeters: state.selectedRadius,
                    search: query.trim(),
                  ));
            }
          },
          decoration: InputDecoration(
            hintText: 'Search places near you (e.g. temple, hotel, cafe)...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Colors.black54, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Colors.black54, size: 18),
                    onPressed: () {
                      _searchDebounceTimer?.cancel();
                      _searchController.clear();
                      context.read<PoiBloc>().add(const UpdateSearchQuery(''));
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return BlocBuilder<PoiBloc, PoiState>(
      buildWhen: (previous, current) =>
          previous.selectedType != current.selectedType,
      builder: (context, state) {
        return Container(
          color: Colors.white,
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = state.selectedType == cat['type'];
              final color = cat['color'] as Color;

              return ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  cat['icon'] as IconData,
                  size: 17,
                  color: isSelected ? Colors.white : color,
                ),
                label: Text(
                  cat['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: color,
                backgroundColor: color.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? color : color.withOpacity(0.25),
                  ),
                ),
                onSelected: (_) {
                  _searchController.clear();
                  context.read<PoiBloc>().add(const UpdateSearchQuery(''));
                  context
                      .read<PoiBloc>()
                      .add(SelectCategory(cat['type'] as String));
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSubtypeFilter(BuildContext context) {
    return BlocBuilder<PoiBloc, PoiState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is PoiLoaded && current is PoiLoaded) {
          return previous.selectedSubType != current.selectedSubType ||
              previous.pois.length != current.pois.length;
        }
        return false;
      },
      builder: (context, state) {
        if (state is! PoiLoaded) return const SizedBox.shrink();

        final subTypeCounts = state.availableSubTypes;
        if (subTypeCounts.isEmpty || subTypeCounts.length <= 1) {
          return const SizedBox.shrink();
        }

        final selectedSub = state.selectedSubType;

        return Container(
          color: Colors.white,
          height: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              // "All" filter chip
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  showCheckmark: false,
                  label: Text('All (${state.pois.length})'),
                  selected: selectedSub == null || selectedSub == 'all',
                  selectedColor: Colors.black87,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: (selectedSub == null || selectedSub == 'all')
                        ? Colors.white
                        : Colors.black87,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onSelected: (_) {
                    context.read<PoiBloc>().add(const SelectSubType('all'));
                  },
                ),
              ),

              // Individual subType filter chips
              ...subTypeCounts.entries.map((entry) {
                final subKey = entry.key;
                final count = entry.value;
                final isSelected = selectedSub == subKey;
                final label = _formatSubtypeLabel(subKey);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    showCheckmark: false,
                    label: Text('$label ($count)'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    backgroundColor: Colors.indigo.shade50.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.indigo.shade100,
                      ),
                    ),
                    onSelected: (_) {
                      context
                          .read<PoiBloc>()
                          .add(SelectSubType(isSelected ? 'all' : subKey));
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatSubtypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'lodge':
        return 'Small Lodges';
      case 'guest_house':
        return 'Guest Houses';
      case 'homestay':
        return 'Homestays';
      case 'hostel':
        return 'Hostels';
      case 'hotel':
        return 'Hotels';
      case 'resort':
        return 'Resorts';
      case 'dharamshala':
        return 'Dharamshalas';
      case 'temple':
        return 'Temples & Shrines';
      case 'fort':
        return 'Historic Forts';
      case 'viewpoint':
        return 'Scenic Viewpoints';
      case 'waterfall':
        return 'Waterfalls';
      case 'beach':
        return 'Beaches';
      case 'museum':
        return 'Museums';
      case 'monument':
        return 'Monuments';
      case 'park':
        return 'Parks & Gardens';
      default:
        return raw.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
    }
  }

  Widget _buildRadiusFilter(BuildContext context) {
    return BlocBuilder<PoiBloc, PoiState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous.selectedRadius != current.selectedRadius) return true;
        if (previous is PoiLoaded && current is PoiLoaded) {
          return previous.filteredPois.length != current.filteredPois.length;
        }
        return false;
      },
      builder: (context, state) {
        final count = state is PoiLoaded ? state.filteredPois.length : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count != null ? '$count places found' : 'Search distance:',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Row(
                children: _radii.map((radius) {
                  final isSelected = state.selectedRadius == radius;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.read<PoiBloc>().add(SelectRadius(radius));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '${radius ~/ 1000} km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPoiList(BuildContext context, List<PoiEntity> pois) {
    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: () async {
        final state = context.read<PoiBloc>().state;
        context.read<PoiBloc>().add(LoadNearbyPOIs(
              type: state.selectedType,
              radiusMeters: state.selectedRadius,
            ));
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pois.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final poi = pois[index];
          final cat = _categories.firstWhere(
            (c) => c['type'] == poi.type,
            orElse: () => {
              'icon': Icons.place_rounded,
              'color': Colors.blueGrey,
              'label': 'Place',
            },
          );
          final color = poi.subTypeColor;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat['icon'] as IconData,
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              poi.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Subtype Tag Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: color.withOpacity(0.25)),
                                  ),
                                  child: Text(
                                    poi.displaySubType,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                // Distance Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    poi.formattedDistance.isNotEmpty
                                        ? poi.formattedDistance
                                        : 'Nearby',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                                if (poi.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            size: 13, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          poi.rating!.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (poi.address != null && poi.address!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            poi.address!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // View on Map Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapPage(targetPoi: poi),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: const Text('View on Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Details Button
                      OutlinedButton.icon(
                        onPressed: () {
                          _showPoiDetails(context, poi, cat);
                        },
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: const Text('Details'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPoiDetails(
      BuildContext context, PoiEntity poi, Map<String, dynamic> cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: poi.subTypeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat['icon'] as IconData,
                        color: poi.subTypeColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: poi.subTypeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                poi.displaySubType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: poi.subTypeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              poi.formattedDistance.isNotEmpty
                                  ? poi.formattedDistance
                                  : 'Nearby',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (poi.address != null && poi.address!.isNotEmpty) ...[
                _buildDetailRow(
                    Icons.location_on_outlined, 'Address', poi.address!),
                const SizedBox(height: 10),
              ],
              if (poi.phone != null && poi.phone!.isNotEmpty) ...[
                _buildDetailRow(Icons.phone_outlined, 'Phone', poi.phone!),
                const SizedBox(height: 10),
              ],
              if (poi.website != null && poi.website!.isNotEmpty) ...[
                _buildDetailRow(Icons.language_rounded, 'Website', poi.website!),
                const SizedBox(height: 10),
              ],
              _buildDetailRow(
                Icons.pin_drop_outlined,
                'Coordinates',
                '${poi.lat.toStringAsFixed(5)}, ${poi.lng.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 10),
              _buildDetailRow(Icons.tag_rounded, 'OSM Source ID', poi.osmId),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapPage(targetPoi: poi),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Open on Interactive Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String type,
    int radius,
    String searchQuery,
    String? subType,
  ) {
    final catName = type.replaceFirst('_', ' ');
    final subDesc = subType != null && subType != 'all'
        ? ' in category "$subType"'
        : '';
    final searchDesc =
        searchQuery.isNotEmpty ? ' matching "$searchQuery"' : '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.explore_off_rounded,
                  size: 48, color: Colors.indigo.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${catName}s Found$subDesc$searchDesc',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No places found within ${(radius / 1000).toStringAsFixed(1)} km.\nTry selecting a larger search distance chip above (e.g. 3 km or 5 km) or trying another filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                final nextRadius = radius >= 5000 ? 10000 : radius + 2000;
                context.read<PoiBloc>().add(SelectRadius(nextRadius));
              },
              icon: const Icon(Icons.radar_rounded, size: 18),
              label: Text('Expand Radius to ${((radius >= 5000 ? 10000 : radius + 2000) / 1000).toInt()} km'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Unable to load nearby places',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final state = context.read<PoiBloc>().state;
                context.read<PoiBloc>().add(LoadNearbyPOIs(
                      type: state.selectedType,
                      radiusMeters: state.selectedRadius,
                    ));
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingStateWithTimeout extends StatefulWidget {
  final VoidCallback onRetry;
  const _LoadingStateWithTimeout({required this.onRetry});

  @override
  State<_LoadingStateWithTimeout> createState() => _LoadingStateWithTimeoutState();
}

class _LoadingStateWithTimeoutState extends State<_LoadingStateWithTimeout> {
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          _timedOut = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.timer_outlined, size: 42, color: Colors.amber.shade800),
              ),
              const SizedBox(height: 16),
              const Text(
                'Search is taking longer than expected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'OpenStreetMap servers are taking a while to respond. You can try again or select a smaller search radius.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _timedOut = false;
                  });
                  _timer?.cancel();
                  _timer = Timer(const Duration(seconds: 20), () {
                    if (mounted) {
                      setState(() {
                        _timedOut = true;
                      });
                    }
                  });
                  widget.onRetry();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
          ),
          SizedBox(height: 16),
          Text(
            'Finding nearby places...',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
