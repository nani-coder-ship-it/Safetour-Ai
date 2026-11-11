import '../entities/emergency_contact_entity.dart';
import '../repositories/auth_repository.dart';

class UpdateEmergencyContacts {
  final AuthRepository repository;

  UpdateEmergencyContacts(this.repository);

  Future<List<EmergencyContactEntity>> call(
      List<EmergencyContactEntity> contacts) async {
    return await repository.updateEmergencyContacts(contacts);
  }
}
