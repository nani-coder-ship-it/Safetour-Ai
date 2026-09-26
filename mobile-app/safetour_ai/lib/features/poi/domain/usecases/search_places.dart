import '../entities/poi_entity.dart';
import '../repositories/poi_repository.dart';

class SearchPlaces {
  final PoiRepository repository;

  SearchPlaces(this.repository);

  Future<List<PoiEntity>> call(String query, {double? lat, double? lng}) async {
    return await repository.searchPlaces(query, lat: lat, lng: lng);
  }
}
