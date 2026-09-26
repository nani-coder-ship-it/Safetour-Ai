import '../entities/poi_entity.dart';
import '../repositories/poi_repository.dart';

class GetNearbyPOIs {
  final PoiRepository repository;

  GetNearbyPOIs(this.repository);

  Future<List<PoiEntity>> call({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  }) async {
    return await repository.getNearbyPOIs(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      type: type,
      subType: subType,
      search: search,
    );
  }
}
