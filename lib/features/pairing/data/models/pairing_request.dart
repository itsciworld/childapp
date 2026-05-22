/// Payload sent to `POST /api/children/verify-pairing-code`.
///
/// The pairing code is generated on the parent's Vigil app; the child app
/// submits it together with the parent's email to link the two devices.
class PairingRequest {
  const PairingRequest({required this.email, required this.code});

  /// Parent's email — carried over from the login screen.
  final String email;

  /// Pairing code shown on the parent's Vigil app.
  final String code;

  Map<String, dynamic> toJson() => {
        'code': code,
        'email': email,
      };
}
