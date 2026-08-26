import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Chiffrement/déchiffrement d'un texte avec une passphrase utilisateur.
///
/// Format binaire : "MLB1" | salt(16) | iv(12) | ciphertext+tag.
/// Clé dérivée par PBKDF2-HMAC-SHA256 (100k itérations), chiffrement AES-256-GCM.
class CryptoBox {
  CryptoBox._();

  static const _magic = 'MLB1';
  static const _iterations = 100000;

  static SecureRandom _secureRandom() {
    final rnd = FortunaRandom();
    final seedSource = Random.secure();
    final seed = Uint8List.fromList(
        List<int>.generate(32, (_) => seedSource.nextInt(256)));
    rnd.seed(KeyParameter(seed));
    return rnd;
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, _iterations, 32));
    return derivator.process(
        Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Chiffre [plaintext] et renvoie l'archive binaire portable.
  static Uint8List encryptString(String plaintext, String passphrase) {
    final rnd = _secureRandom();
    final salt = rnd.nextBytes(16);
    final iv = rnd.nextBytes(12);
    final key = _deriveKey(passphrase, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final ct = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

    final out = BytesBuilder();
    out.add(ascii.encode(_magic));
    out.add(salt);
    out.add(iv);
    out.add(ct);
    return out.toBytes();
  }

  /// Déchiffre une archive produite par [encryptString].
  /// Lève [CryptoException] si la passphrase est fausse ou le fichier invalide.
  static String decryptToString(Uint8List data, String passphrase) {
    if (data.length < 4 + 16 + 12 + 16 ||
        ascii.decode(data.sublist(0, 4)) != _magic) {
      throw CryptoException('Fichier de sauvegarde invalide.');
    }
    final salt = data.sublist(4, 20);
    final iv = data.sublist(20, 32);
    final ct = data.sublist(32);
    final key = _deriveKey(passphrase, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    try {
      final pt = cipher.process(ct);
      return utf8.decode(pt);
    } on InvalidCipherTextException {
      throw CryptoException('Passphrase incorrecte ou fichier corrompu.');
    }
  }
}

class CryptoException implements Exception {
  CryptoException(this.message);
  final String message;
  @override
  String toString() => message;
}
