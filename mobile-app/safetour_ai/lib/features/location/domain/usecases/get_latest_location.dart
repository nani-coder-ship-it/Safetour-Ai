import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

class GetLatestLocation {
  final LocationRepository repository;

  GetLatestLocation(this.repository);

  Future<LocationEntity?> call(String userId) async {
    return await repository.getLatestLocation(userId);
  }
}
