abstract class DigitalIdEvent {
  const DigitalIdEvent();
}

class LoadDigitalId extends DigitalIdEvent {
  final bool silent;
  const LoadDigitalId({this.silent = false});
}

class UpdateDigitalIdProfile extends DigitalIdEvent {
  final Map<String, dynamic> updates;
  const UpdateDigitalIdProfile(this.updates);
}

class VerifyDigitalIdOnChain extends DigitalIdEvent {
  final String identifier;
  const VerifyDigitalIdOnChain(this.identifier);
}
