import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import '../../domain/entities/emergency_contact_entity.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String name, String email, String password);
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
  Future<List<EmergencyContactModel>> getEmergencyContacts();
  Future<List<EmergencyContactModel>> updateEmergencyContacts(List<EmergencyContactEntity> contacts);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final DioClient dioClient;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.dioClient,
  });

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        return UserModel(
          id: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? '',
          role: 'user', // Default or fetch from backend
        );
      } else {
        throw AuthException('Login returned null user');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Firebase Auth Error');
    }
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        
        // Call backend to create profile record
        await dioClient.dio.post('/auth/register', data: {
          'uid': user.uid,
          'email': user.email ?? email,
          'name': name,
        });

        return UserModel(
          id: user.uid,
          email: user.email ?? email,
          name: name,
          role: 'user',
        );
      } else {
        throw AuthException('Registration returned null user');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Firebase Auth Error');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      return UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? '',
        role: 'user',
      );
    }
    return null;
  }

  @override
  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    try {
      final response = await dioClient.dio.get('/auth/me');
      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data['data'] as Map<String, dynamic>?;
        final contactsRaw = userData?['emergencyContacts'] as List<dynamic>? ?? [];
        return contactsRaw
            .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(response.data?['message'] ?? 'Failed to fetch emergency contacts');
      }
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException(e.message ?? 'Network error fetching emergency contacts');
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<EmergencyContactModel>> updateEmergencyContacts(
      List<EmergencyContactEntity> contacts) async {
    try {
      final payload = contacts.map((c) => EmergencyContactModel.fromEntity(c).toJson()).toList();
      final response = await dioClient.dio.put('/auth/me', data: {
        'emergencyContacts': payload,
      });

      if (response.statusCode == 200 && response.data != null) {
        final userData = response.data['data'] as Map<String, dynamic>?;
        final contactsRaw = userData?['emergencyContacts'] as List<dynamic>? ?? [];
        return contactsRaw
            .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(response.data?['message'] ?? 'Failed to update emergency contacts');
      }
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException(e.message ?? 'Network error updating emergency contacts');
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }
}
