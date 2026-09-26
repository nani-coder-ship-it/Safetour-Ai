import '../entities/location_entity.dart';

abstract class LocationRepository {
  Future<List<String>> sendLocation(LocationEntity location);
  Future<LocationEntity?> getLatestLocation(String userId);
}
