import '../../domain/entities/user_entity.dart';
import 'emergency_contact_model.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.role,
    super.phone,
    super.emergencyContacts = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final contactsList = (json['emergencyContacts'] as List<dynamic>?)
            ?.map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? json['firebaseUid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'tourist',
      phone: json['phone']?.toString(),
      emergencyContacts: contactsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'emergencyContacts': emergencyContacts
          .map((c) => EmergencyContactModel.fromEntity(c).toJson())
          .toList(),
    };
  }
}
