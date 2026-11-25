import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/features/app_protection/data/pin_credential_service.dart';

void main() {
  test('stores a salted verifier and verifies only the correct PIN', () async {
    final store = _MemoryPinCredentialStore();
    final service = PinCredentialService(store);

    await service.setPin('4826');

    expect(await service.isPinConfigured(), isTrue);
    expect(store.value, isNot(contains('4826')));
    expect(await service.verifyPin('4826'), isTrue);
    expect(await service.verifyPin('1234'), isFalse);
  });

  test('rejects invalid PIN formats', () async {
    final service = PinCredentialService(_MemoryPinCredentialStore());

    await expectLater(service.setPin('123'), throwsFormatException);
    await expectLater(service.setPin('12a4'), throwsFormatException);
    expect(await service.verifyPin('123'), isFalse);
  });
}

class _MemoryPinCredentialStore implements PinCredentialStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
