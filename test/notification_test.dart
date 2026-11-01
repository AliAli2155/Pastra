import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/notifications/notification_service.dart';

class _Fake implements NotificationBackend {
  final List<String> log = <String>[];
  @override
  Future<void> init() async => log.add('init');
  @override
  Future<void> show(NotificationKind kind, {required String title, required String body, String? payload}) async =>
      log.add('show:${kind.name}:$payload');
  @override
  Future<void> scheduleDaily(NotificationKind kind, {required int hour, required int minute, required String title, required String body}) async =>
      log.add('daily:$hour:$minute');
  @override
  Future<void> cancel(NotificationKind kind) async => log.add('cancel:${kind.name}');
}

void main() {
  tearDown(() {
    NotificationService.instance
      ..detach()
      ..enabled = true
      ..asked.clear();
  });

  test('without a backend every call is harmless', () async {
    final n = NotificationService.instance;
    expect(n.available, isFalse);
    await n.friendRequest(from: 'Ali', title: 't', body: 'b');
    await n.scheduleQuestReminder(title: 't', body: 'b');
  });

  test('requests, invites and the daily reminder reach the backend', () async {
    final fake = _Fake();
    final n = NotificationService.instance;
    await n.attach(fake);
    await n.friendRequest(from: 'Ali', title: 't', body: 'b');
    await n.invite(from: 'Ali', code: '1234', title: 't', body: 'b');
    await n.scheduleQuestReminder(title: 't', body: 'b');
    await n.cancelQuestReminder();
    expect(fake.log, <String>['init', 'show:friendRequest:friends', 'show:invite:room:1234', 'daily:19:0', 'cancel:dailyQuests']);
  });

  test('turned off, nothing is shown', () async {
    final fake = _Fake();
    final n = NotificationService.instance..enabled = false;
    await n.attach(fake);
    await n.friendRequest(from: 'Ali', title: 't', body: 'b');
    expect(fake.log, <String>['init']);
  });
}
