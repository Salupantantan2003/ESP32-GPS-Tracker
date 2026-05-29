import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  final String _salt;

  PasswordHasher(this._salt);

  String hash(String password) {
    final bytes = utf8.encode(password + _salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class AuthService {
  // ensure _jwtSecret is defined in this class
  final String _jwtSecret = 'REPLACE_WITH_YOUR_SECRET';

  String _signToken(String data) {
    final key = utf8.encode(_jwtSecret);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // optional helper if you need to encode arbitrary bytes as base64url
  String _encodeBase64Url(List<int> bytes) {
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}