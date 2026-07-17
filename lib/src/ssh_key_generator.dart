import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/export.dart';

/// Service to programmatically generate and format SSH Key pairs (RSA 2048) in Dart.
class SshKeyGenerator {
  /// Generate an RSA 2048-bit SSH Key Pair asynchronously using a background Isolate.
  ///
  /// Returns a map with:
  /// - 'privateKey': PKCS#1 PEM private key string
  /// - 'publicKey': OpenSSH formatted public key string
  static Future<Map<String, String>> generateSshKeyPair({String comment = 'easy-unraid-client'}) async {
    return compute(_generateKeyPairTask, comment);
  }

  /// Top-level task execution inside Isolate.
  static Map<String, String> _generateKeyPairTask(dynamic arg) {
    final comment = arg as String;
    // 1. Initialize secure random
    final secureRandom = _createSecureRandom();

    // 2. Setup RSA key generator parameters (2048 bits)
    final params = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 12);
    final keyGenerator = RSAKeyGenerator();
    keyGenerator.init(ParametersWithRandom(params, secureRandom));

    // 3. Generate key pair
    final keyPair = keyGenerator.generateKeyPair();
    final privateKey = keyPair.privateKey;
    final publicKey = keyPair.publicKey;

    // 4. Format to SSH compatible strings
    final privateKeyPem = _encodePrivateKeyToPem(privateKey, publicKey.exponent!);
    final publicKeySsh = _encodePublicKeyToSsh(publicKey, comment);

    return {
      'privateKey': privateKeyPem,
      'publicKey': publicKeySsh,
    };
  }

  /// Create a cryptographically secure random generator using PointyCastle Fortuna.
  static SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Encodes RSAPrivateKey object to PKCS#1 PEM string.
  static String _encodePrivateKeyToPem(RSAPrivateKey privateKey, BigInt publicExponent) {
    final topLevel = ASN1Sequence();
    topLevel.add(ASN1Integer(BigInt.from(0))); // Version
    topLevel.add(ASN1Integer(privateKey.n!));
    topLevel.add(ASN1Integer(publicExponent));
    topLevel.add(ASN1Integer(privateKey.privateExponent!));
    topLevel.add(ASN1Integer(privateKey.p!));
    topLevel.add(ASN1Integer(privateKey.q!));
    topLevel.add(ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one))); // dP
    topLevel.add(ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one))); // dQ
    topLevel.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!))); // qInv

    final data = topLevel.encodedBytes;
    final base64Data = base64.encode(data);
    
    // Format to 64 character lines (PEM Standard)
    final chunks = [];
    for (var i = 0; i < base64Data.length; i += 64) {
      chunks.add(base64Data.substring(i, min(i + 64, base64Data.length)));
    }
    final formattedBase64 = chunks.join('\n');
    return '-----BEGIN RSA PRIVATE KEY-----\n$formattedBase64\n-----END RSA PRIVATE KEY-----';
  }

  /// Encodes RSAPublicKey object to standard OpenSSH public key format (ssh-rsa).
  static String _encodePublicKeyToSsh(RSAPublicKey publicKey, String comment) {
    final buffer = BytesBuilder();
    buffer.add(_encodeStringToSsh('ssh-rsa'));
    buffer.add(_encodeBigIntToSsh(publicKey.exponent!));
    buffer.add(_encodeBigIntToSsh(publicKey.n!));

    final base64Key = base64.encode(buffer.toBytes());
    return 'ssh-rsa $base64Key $comment';
  }

  /// Serialize string to SSH format (4-byte length + string bytes).
  static Uint8List _encodeStringToSsh(String str) {
    final bytes = utf8.encode(str);
    final length = bytes.length;
    final result = Uint8List(4 + length);
    result[0] = (length >> 24) & 0xFF;
    result[1] = (length >> 16) & 0xFF;
    result[2] = (length >> 8) & 0xFF;
    result[3] = length & 0xFF;
    result.setRange(4, result.length, bytes);
    return result;
  }

  /// Serialize BigInt to SSH format (4-byte length + signed big-endian bytes).
  static Uint8List _encodeBigIntToSsh(BigInt number) {
    var rawBytes = _encodeBigIntToBytes(number);
    
    // Prepend 0x00 if the MSB is set, to ensure it is interpreted as positive.
    if (rawBytes.isNotEmpty && (rawBytes[0] & 0x80) != 0) {
      var zeroBytes = Uint8List(rawBytes.length + 1);
      zeroBytes[0] = 0x00;
      zeroBytes.setRange(1, zeroBytes.length, rawBytes);
      rawBytes = zeroBytes;
    }

    final length = rawBytes.length;
    final result = Uint8List(4 + length);
    result[0] = (length >> 24) & 0xFF;
    result[1] = (length >> 16) & 0xFF;
    result[2] = (length >> 8) & 0xFF;
    result[3] = length & 0xFF;
    result.setRange(4, result.length, rawBytes);
    return result;
  }

  /// Helper to convert BigInt to big-endian bytes.
  static Uint8List _encodeBigIntToBytes(BigInt number) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final l = hex.length ~/ 2;
    final result = Uint8List(l);
    for (var i = 0; i < l; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
