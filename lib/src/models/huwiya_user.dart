
class HuwiyaUser {
  
  final String id;

  final String name;
  final String locale;
  final String zoneinfo;
  final String theme;
  final List<String> scopes;

  
  final String? iss;
  final String? aud;
  final DateTime? iat;
  final DateTime? exp;

  const HuwiyaUser({
    required this.id,
    required this.name,
    required this.locale,
    required this.zoneinfo,
    required this.theme,
    required this.scopes,
    this.iss,
    this.aud,
    this.iat,
    this.exp,
  });

  factory HuwiyaUser.fromClaims(Map<String, dynamic> claims) {
    return HuwiyaUser(
      id: claims['id'] as String,
      name: claims['name'] as String,
      locale: claims['locale'] as String,
      zoneinfo: claims['zoneinfo'] as String,
      theme: claims['theme'] as String,
      scopes: (claims['scopes'] as List<dynamic>).cast<String>(),
      iss: claims['iss'] as String?,
      aud: claims['aud'] as String?,
      iat: claims['iat'] != null
          ? DateTime.fromMillisecondsSinceEpoch((claims['iat'] as num).toInt() * 1000)
          : null,
      exp: claims['exp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((claims['exp'] as num).toInt() * 1000)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locale': locale,
        'zoneinfo': zoneinfo,
        'theme': theme,
        'scopes': scopes,
        if (iss != null) 'iss': iss,
        if (aud != null) 'aud': aud,
        if (iat != null) 'iat': iat!.millisecondsSinceEpoch ~/ 1000,
        if (exp != null) 'exp': exp!.millisecondsSinceEpoch ~/ 1000,
      };

  @override
  String toString() => 'HuwiyaUser(id: $id, name: $name, locale: $locale)';
}
