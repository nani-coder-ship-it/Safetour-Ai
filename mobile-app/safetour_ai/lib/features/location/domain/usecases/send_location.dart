import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

class SendLocation {
  final LocationRepository repository;

  SendLocation(this.repository);

  Future<List<String>> call(LocationEntity location) async {
    return await repository.sendLocation(location);
  }
}
