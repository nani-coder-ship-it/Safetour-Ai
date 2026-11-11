import '../entities/emergency_contact_entity.dart';
import '../repositories/auth_repository.dart';

class GetEmergencyContacts {
  final AuthRepository repository;

  GetEmergencyContacts(this.repository);

  Future<List<EmergencyContactEntity>> call() async {
    return await repository.getEmergencyContacts();
  }
}
