import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_cycle/services/notification_service.dart';

void main() {
  test('exposes a single notification service instance', () {
    expect(NotificationService.instance, same(NotificationService.instance));
  });

  test('rejects period reminder lead times outside 0-3 days', () async {
    await expectLater(
      NotificationService.instance.schedulePeriodReminder(
        predictedPeriodDate: DateTime(2026, 12, 1),
        time: const TimeOfDay(hour: 9, minute: 0),
        daysBefore: 4,
      ),
      throwsArgumentError,
    );
  });

  test('rejects ovulation reminder lead times outside 0-3 days', () async {
    await expectLater(
      NotificationService.instance.scheduleOvulationReminder(
        predictedOvulationDate: DateTime(2026, 12, 1),
        time: const TimeOfDay(hour: 9, minute: 0),
        daysBefore: -1,
      ),
      throwsArgumentError,
    );
  });
}
