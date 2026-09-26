import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String name, String email, String password);
  Future<UserModel?> getCurrentUser();
  Future<void> logout();
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
}
