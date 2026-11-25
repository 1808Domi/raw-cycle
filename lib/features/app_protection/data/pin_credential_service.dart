import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class PinCredentialRepository {
  Future<bool> isPinConfigured();

  Future<void> setPin(String pin);

  Future<bool> verifyPin(String pin);
}

abstract interface class PinCredentialStore {
  Future<String?> read();

  Future<void> write(String value);
}

class PinCredentialService implements PinCredentialRepository {
  PinCredentialService(this._store);

  static final instance = PinCredentialService(
    _FlutterSecurePinStore(FlutterSecureStorage()),
  );

  static const _minimumPinLength = 4;
  static const _maximumPinLength = 12;
  static const _keyDerivationIterations = 100000;
  static const _saltLength = 16;

  static final _keyDerivation = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _keyDerivationIterations,
    bits: 256,
  );

  final PinCredentialStore _store;

  static bool isValidPin(String pin) {
    return pin.length >= _minimumPinLength &&
        pin.length <= _maximumPinLength &&
        RegExp(r'^\d+$').hasMatch(pin);
  }

  @override
  Future<bool> isPinConfigured() async => await _readCredential() != null;

  @override
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw const FormatException('Die PIN muss 4 bis 12 Ziffern enthalten.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(
      _saltLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    final hash = await _deriveHash(pin, salt);
    await _store.write(
      jsonEncode({'salt': base64Encode(salt), 'hash': base64Encode(hash)}),
    );
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (!isValidPin(pin)) {
      return false;
    }

    final credential = await _readCredential();
    if (credential == null) {
      return false;
    }
    final actualHash = await _deriveHash(pin, credential.salt);
    return _constantTimeEquals(actualHash, credential.hash);
  }

  Future<_PinCredential?> _readCredential() async {
    final value = await _store.read();
    if (value == null) {
      return null;
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['salt'] is! String ||
        decoded['hash'] is! String) {
      throw const FormatException(
        'Der gespeicherte PIN-Datensatz ist ungültig.',
      );
    }

    final salt = base64Decode(decoded['salt'] as String);
    final hash = base64Decode(decoded['hash'] as String);
    if (salt.length != _saltLength || hash.length != 32) {
      throw const FormatException(
        'Der gespeicherte PIN-Datensatz ist ungültig.',
      );
    }
    return _PinCredential(salt: salt, hash: hash);
  }

  Future<List<int>> _deriveHash(String pin, List<int> salt) async {
    final secretKey = await _keyDerivation.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  bool _constantTimeEquals(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

class _FlutterSecurePinStore implements PinCredentialStore {
  _FlutterSecurePinStore(this._storage);

  static const _credentialKey = 'raw_cycle_app_pin_credential_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _credentialKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _credentialKey, value: value);
}

class _PinCredential {
  const _PinCredential({required this.salt, required this.hash});

  final List<int> salt;
  final List<int> hash;
}
