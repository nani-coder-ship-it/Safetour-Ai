import '../entities/poi_entity.dart';

abstract class PoiRepository {
  Future<List<PoiEntity>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  });

  Future<List<PoiEntity>> searchPlaces(String query, {double? lat, double? lng});
}
