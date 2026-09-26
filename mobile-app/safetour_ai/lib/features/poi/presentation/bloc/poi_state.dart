import '../../domain/entities/poi_entity.dart';

abstract class PoiState {
  final String selectedType;
  final int selectedRadius;
  final String? selectedSubType;
  final String searchQuery;

  const PoiState({
    this.selectedType = 'hotel',
    this.selectedRadius = 3000,
    this.selectedSubType,
    this.searchQuery = '',
  });
}

class PoiInitial extends PoiState {
  const PoiInitial()
      : super(
          selectedType: 'hotel',
          selectedRadius: 3000,
          selectedSubType: null,
          searchQuery: '',
        );
}

class PoiLoading extends PoiState {
  const PoiLoading({
    super.selectedType,
    super.selectedRadius,
    super.selectedSubType,
    super.searchQuery,
  });
}

class PoiLoaded extends PoiState {
  final List<PoiEntity> pois;
  final double userLat;
  final double userLng;

  const PoiLoaded({
    required this.pois,
    required this.userLat,
    required this.userLng,
    super.selectedType,
    super.selectedRadius,
    super.selectedSubType,
    super.searchQuery,
  });

  /// Dynamically filtered POIs according to active subType and search term
  List<PoiEntity> get filteredPois {
    return pois.where((p) {
      if (selectedSubType != null &&
          selectedSubType != 'all' &&
          selectedSubType!.isNotEmpty) {
        if ((p.subType ?? '').toLowerCase() != selectedSubType!.toLowerCase()) {
          return false;
        }
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchSub = (p.subType ?? '').toLowerCase().contains(q);
        final matchAddr = (p.address ?? '').toLowerCase().contains(q);
        if (!matchName && !matchSub && !matchAddr) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Extracts all distinct subTypes present in current loaded POIs with their count
  Map<String, int> get availableSubTypes {
    final map = <String, int>{};
    for (final p in pois) {
      final st = (p.subType ?? 'other').toLowerCase();
      map[st] = (map[st] ?? 0) + 1;
    }
    return map;
  }

  PoiLoaded copyWith({
    List<PoiEntity>? pois,
    double? userLat,
    double? userLng,
    String? selectedType,
    int? selectedRadius,
    String? selectedSubType,
    bool clearSubType = false,
    String? searchQuery,
  }) {
    return PoiLoaded(
      pois: pois ?? this.pois,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      selectedType: selectedType ?? this.selectedType,
      selectedRadius: selectedRadius ?? this.selectedRadius,
      selectedSubType: clearSubType ? null : (selectedSubType ?? this.selectedSubType),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class PoiError extends PoiState {
  final String message;

  const PoiError({
    required this.message,
    super.selectedType,
    super.selectedRadius,
    super.selectedSubType,
    super.searchQuery,
  });
}
