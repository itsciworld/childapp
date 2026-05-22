/// Parsed result of `POST /api/children/verify-pairing-code`.
///
/// This endpoint only confirms the pairing — it returns a `msg` and neither a
/// child id nor a token.
class PairingResponse {
  const PairingResponse({this.message});

  /// Server message, e.g. "Pairing code verified successfully".
  final String? message;

  factory PairingResponse.fromJson(Map<String, dynamic> json) {
    return PairingResponse(
      message: json['msg'] as String? ?? json['message'] as String?,
    );
  }
}
