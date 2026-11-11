import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/digital_id_remote_datasource.dart';
import 'digital_id_event.dart';
import 'digital_id_state.dart';

class DigitalIdBloc extends Bloc<DigitalIdEvent, DigitalIdState> {
  final DigitalIdRemoteDataSource remoteDataSource;

  DigitalIdBloc({required this.remoteDataSource}) : super(const DigitalIdInitial()) {
    on<LoadDigitalId>(_onLoadDigitalId);
    on<UpdateDigitalIdProfile>(_onUpdateProfile);
    on<VerifyDigitalIdOnChain>(_onVerifyOnChain);
  }

  Future<void> _onLoadDigitalId(LoadDigitalId event, Emitter<DigitalIdState> emit) async {
    if (!event.silent && state is! DigitalIdLoaded) {
      emit(const DigitalIdLoading());
    }

    try {
      final digitalId = await remoteDataSource.getMyDigitalId();
      emit(DigitalIdLoaded(digitalId: digitalId));
    } catch (e) {
      if (state is! DigitalIdLoaded) {
        emit(DigitalIdError(e.toString()));
      }
    }
  }

  Future<void> _onUpdateProfile(UpdateDigitalIdProfile event, Emitter<DigitalIdState> emit) async {
    if (state is DigitalIdLoaded) {
      final current = state as DigitalIdLoaded;
      try {
        final updated = await remoteDataSource.updateDigitalId(event.updates);
        emit(current.copyWith(digitalId: updated, message: 'Profile updated & re-anchored'));
      } catch (e) {
        emit(current.copyWith(message: 'Failed to update: $e'));
      }
    }
  }

  Future<void> _onVerifyOnChain(VerifyDigitalIdOnChain event, Emitter<DigitalIdState> emit) async {
    if (state is DigitalIdLoaded) {
      final current = state as DigitalIdLoaded;
      emit(current.copyWith(isVerifying: true));

      try {
        final result = await remoteDataSource.verifyOnChain(event.identifier);
        emit(current.copyWith(
          isVerifying: false,
          verificationResult: result,
          message: result['verified'] == true
              ? 'Cryptographic integrity verified on SafeTour Ledger'
              : 'Verification check failed',
        ));
      } catch (e) {
        emit(current.copyWith(
          isVerifying: false,
          verificationResult: {'verified': false, 'message': e.toString()},
          message: 'Verification check failed',
        ));
      }
    }
  }
}
