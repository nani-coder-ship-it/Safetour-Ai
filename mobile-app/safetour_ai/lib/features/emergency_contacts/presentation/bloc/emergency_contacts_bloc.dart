import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/emergency_contact_entity.dart';
import '../../../auth/domain/usecases/get_emergency_contacts.dart';
import '../../../auth/domain/usecases/update_emergency_contacts.dart';
import 'emergency_contacts_event.dart';
import 'emergency_contacts_state.dart';

class EmergencyContactsBloc
    extends Bloc<EmergencyContactsEvent, EmergencyContactsState> {
  final GetEmergencyContacts getEmergencyContacts;
  final UpdateEmergencyContacts updateEmergencyContacts;

  EmergencyContactsBloc({
    required this.getEmergencyContacts,
    required this.updateEmergencyContacts,
  }) : super(const EmergencyContactsInitial()) {
    on<LoadEmergencyContacts>(_onLoadEmergencyContacts);
    on<AddEmergencyContact>(_onAddEmergencyContact);
    on<EditEmergencyContact>(_onEditEmergencyContact);
    on<DeleteEmergencyContact>(_onDeleteEmergencyContact);
  }

  Future<void> _onLoadEmergencyContacts(
    LoadEmergencyContacts event,
    Emitter<EmergencyContactsState> emit,
  ) async {
    emit(EmergencyContactsLoading(contacts: state.contacts));
    try {
      final contacts = await getEmergencyContacts();
      emit(EmergencyContactsLoaded(contacts));
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      emit(EmergencyContactsError(
        message: msg,
        contacts: state.contacts,
      ));
    }
  }

  Future<void> _onAddEmergencyContact(
    AddEmergencyContact event,
    Emitter<EmergencyContactsState> emit,
  ) async {
    final currentList = List<EmergencyContactEntity>.from(state.contacts);
    if (currentList.length >= 5) {
      emit(EmergencyContactsError(
        message: 'Maximum 5 emergency contacts allowed.',
        contacts: currentList,
      ));
      return;
    }

    emit(EmergencyContactsSaving(currentList));
    final updatedList = [...currentList, event.contact];

    try {
      final syncedList = await updateEmergencyContacts(updatedList);
      emit(EmergencyContactsActionSuccess(
        contacts: syncedList,
        message: 'Contact added successfully!',
      ));
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      emit(EmergencyContactsError(
        message: msg,
        contacts: currentList,
      ));
    }
  }

  Future<void> _onEditEmergencyContact(
    EditEmergencyContact event,
    Emitter<EmergencyContactsState> emit,
  ) async {
    final currentList = List<EmergencyContactEntity>.from(state.contacts);
    if (event.index < 0 || event.index >= currentList.length) {
      emit(EmergencyContactsError(
        message: 'Invalid contact index.',
        contacts: currentList,
      ));
      return;
    }

    emit(EmergencyContactsSaving(currentList));
    final updatedList = List<EmergencyContactEntity>.from(currentList);
    updatedList[event.index] = event.contact;

    try {
      final syncedList = await updateEmergencyContacts(updatedList);
      emit(EmergencyContactsActionSuccess(
        contacts: syncedList,
        message: 'Contact updated successfully!',
      ));
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      emit(EmergencyContactsError(
        message: msg,
        contacts: currentList,
      ));
    }
  }

  Future<void> _onDeleteEmergencyContact(
    DeleteEmergencyContact event,
    Emitter<EmergencyContactsState> emit,
  ) async {
    final currentList = List<EmergencyContactEntity>.from(state.contacts);
    if (event.index < 0 || event.index >= currentList.length) {
      emit(EmergencyContactsError(
        message: 'Invalid contact index.',
        contacts: currentList,
      ));
      return;
    }

    emit(EmergencyContactsSaving(currentList));
    final updatedList = List<EmergencyContactEntity>.from(currentList);
    updatedList.removeAt(event.index);

    try {
      final syncedList = await updateEmergencyContacts(updatedList);
      emit(EmergencyContactsActionSuccess(
        contacts: syncedList,
        message: 'Contact deleted successfully!',
      ));
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      emit(EmergencyContactsError(
        message: msg,
        contacts: currentList,
      ));
    }
  }
}
