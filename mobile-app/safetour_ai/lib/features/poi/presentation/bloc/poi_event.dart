abstract class PoiEvent {
  const PoiEvent();
}

class LoadNearbyPOIs extends PoiEvent {
  final String? type;
  final int? radiusMeters;
  final String? subType;
  final String? search;
  final bool forceRefresh;
  final double? userLat;
  final double? userLng;

  const LoadNearbyPOIs({
    this.type,
    this.radiusMeters,
    this.subType,
    this.search,
    this.forceRefresh = false,
    this.userLat,
    this.userLng,
  });
}

class SelectCategory extends PoiEvent {
  final String type;

  const SelectCategory(this.type);
}

class SelectRadius extends PoiEvent {
  final int radiusMeters;

  const SelectRadius(this.radiusMeters);
}

class SelectSubType extends PoiEvent {
  final String? subType;

  const SelectSubType(this.subType);
}

class UpdateSearchQuery extends PoiEvent {
  final String query;

  const UpdateSearchQuery(this.query);
}
