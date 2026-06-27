class AuthToken {
  final String accessToken;

  /// Refresh token, if the server issued one. OAuth providers commonly return a
  /// `refresh_token` only on the first authorization (fresh consent) and omit it
  /// on subsequent logins, so this may be `null`.
  final String? refreshToken;

  final DateTime expiresAt;

  const AuthToken({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num).toInt();
    return AuthToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    if (refreshToken != null) 'refresh_token': refreshToken,
    'expires_at': expiresAt.toIso8601String(),
  };

  @override
  String toString() => 'AuthToken(expiresAt: $expiresAt)';
}
