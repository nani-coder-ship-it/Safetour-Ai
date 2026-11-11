import '../../data/models/digital_id_model.dart';

abstract class DigitalIdState {
  const DigitalIdState();
}

class DigitalIdInitial extends DigitalIdState {
  const DigitalIdInitial();
}

class DigitalIdLoading extends DigitalIdState {
  const DigitalIdLoading();
}

class DigitalIdLoaded extends DigitalIdState {
  final DigitalIdModel digitalId;
  final bool isVerifying;
  final Map<String, dynamic>? verificationResult;
  final String? message;

  const DigitalIdLoaded({
    required this.digitalId,
    this.isVerifying = false,
    this.verificationResult,
    this.message,
  });

  DigitalIdLoaded copyWith({
    DigitalIdModel? digitalId,
    bool? isVerifying,
    Map<String, dynamic>? verificationResult,
    String? message,
  }) {
    return DigitalIdLoaded(
      digitalId: digitalId ?? this.digitalId,
      isVerifying: isVerifying ?? this.isVerifying,
      verificationResult: verificationResult ?? this.verificationResult,
      message: message,
    );
  }
}

class DigitalIdError extends DigitalIdState {
  final String message;
  const DigitalIdError(this.message);
}
