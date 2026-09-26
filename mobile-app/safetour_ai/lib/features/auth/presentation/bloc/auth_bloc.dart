import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../../../core/errors/failures.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUser loginUser;
  final RegisterUser registerUser;

  AuthBloc({
    required this.loginUser,
    required this.registerUser,
  }) : super(AuthInitial()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  void _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final name = currentUser.displayName ??
          (currentUser.email != null && currentUser.email!.contains('@')
              ? currentUser.email!.split('@')[0]
              : 'Tourist');

      emit(Authenticated(UserEntity(
        id: currentUser.uid,
        email: currentUser.email ?? '',
        name: name,
        role: 'tourist',
      )));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await loginUser(event.email, event.password);
      emit(Authenticated(user));
    } on Failure catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('An unexpected error occurred'));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await registerUser(event.name, event.email, event.password);
      emit(Authenticated(user));
    } on Failure catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('An unexpected error occurred'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    emit(Unauthenticated());
  }
}
