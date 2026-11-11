import '../../../auth/domain/entities/emergency_contact_entity.dart';

abstract class EmergencyContactsEvent {}

class LoadEmergencyContacts extends EmergencyContactsEvent {}

class AddEmergencyContact extends EmergencyContactsEvent {
  final EmergencyContactEntity contact;
  AddEmergencyContact(this.contact);
}

class EditEmergencyContact extends EmergencyContactsEvent {
  final int index;
  final EmergencyContactEntity contact;
  EditEmergencyContact({required this.index, required this.contact});
}

class DeleteEmergencyContact extends EmergencyContactsEvent {
  final int index;
  DeleteEmergencyContact(this.index);
}
