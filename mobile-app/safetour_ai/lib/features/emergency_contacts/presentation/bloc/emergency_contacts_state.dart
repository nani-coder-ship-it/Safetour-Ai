import '../../../auth/domain/entities/emergency_contact_entity.dart';

abstract class EmergencyContactsState {
  final List<EmergencyContactEntity> contacts;
  const EmergencyContactsState({this.contacts = const []});
}

class EmergencyContactsInitial extends EmergencyContactsState {
  const EmergencyContactsInitial() : super(contacts: const []);
}

class EmergencyContactsLoading extends EmergencyContactsState {
  const EmergencyContactsLoading({super.contacts});
}

class EmergencyContactsLoaded extends EmergencyContactsState {
  const EmergencyContactsLoaded(List<EmergencyContactEntity> contacts)
      : super(contacts: contacts);
}

class EmergencyContactsSaving extends EmergencyContactsState {
  const EmergencyContactsSaving(List<EmergencyContactEntity> currentContacts)
      : super(contacts: currentContacts);
}

class EmergencyContactsActionSuccess extends EmergencyContactsState {
  final String message;
  const EmergencyContactsActionSuccess({
    required List<EmergencyContactEntity> contacts,
    required this.message,
  }) : super(contacts: contacts);
}

class EmergencyContactsError extends EmergencyContactsState {
  final String message;
  const EmergencyContactsError({
    required this.message,
    List<EmergencyContactEntity> contacts = const [],
  }) : super(contacts: contacts);
}
