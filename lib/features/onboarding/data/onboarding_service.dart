import 'package:hive_ce/hive.dart';

class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();
  static const _boxName = 'raw_cycle_onboarding';
  static const _completionKey = 'completed';

  Future<void>? _initialization;
  Box<bool>? _box;

  Future<void> init() => _initialization ??= _openBox();

  bool get hasCompletedOnboarding {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('OnboardingService.init() must be called before use.');
    }
    return box.get(_completionKey, defaultValue: false)!;
  }

  Future<void> markCompleted() async {
    await init();
    await _box!.put(_completionKey, true);
  }

  Future<void> _openBox() async {
    _box = await Hive.openBox<bool>(_boxName);
  }
}
