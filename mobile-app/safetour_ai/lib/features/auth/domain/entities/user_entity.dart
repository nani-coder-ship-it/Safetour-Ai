import 'emergency_contact_entity.dart';

class UserEntity {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final List<EmergencyContactEntity> emergencyContacts;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.emergencyContacts = const [],
  });
}
