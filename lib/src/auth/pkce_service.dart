import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PkceValues {
  final String codeVerifier;
  final String codeChallenge;
  final String state;

  const PkceValues({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.state,
  });
}

class PkceService {
  PkceValues generate() {
    final verifier = _generateVerifier();
    final challenge = _deriveChallenge(verifier);
    final state = _generateState();
    return PkceValues(
      codeVerifier: verifier,
      codeChallenge: challenge,
      state: state,
    );
  }

  String _generateVerifier() {
    final bytes = _secureRandomBytes(32);
    return _base64UrlNoPadding(bytes);
  }

  String _deriveChallenge(String verifier) {
    final hash = sha256.convert(utf8.encode(verifier));
    return _base64UrlNoPadding(hash.bytes);
  }

  String _generateState() {
    final bytes = _secureRandomBytes(16);
    return _base64UrlNoPadding(bytes);
  }

  List<int> _secureRandomBytes(int count) {
    final rng = Random.secure();
    return List<int>.generate(count, (_) => rng.nextInt(256));
  }

  String _base64UrlNoPadding(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
