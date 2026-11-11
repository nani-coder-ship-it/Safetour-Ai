import '../entities/user_entity.dart';
import '../entities/emergency_contact_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  
  Future<UserEntity> register(String name, String email, String password);
  
  Future<UserEntity?> getCurrentUser();
  
  Future<void> logout();

  Future<List<EmergencyContactEntity>> getEmergencyContacts();

  Future<List<EmergencyContactEntity>> updateEmergencyContacts(
      List<EmergencyContactEntity> contacts);
}
