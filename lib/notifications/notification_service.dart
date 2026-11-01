import 'package:flutter/foundation.dart';

/// What a notification is about.
enum NotificationKind { invite, friendRequest, dailyQuests }

/// A platform backend (for example `flutter_local_notifications` on Android
/// or FCM). Nothing is plugged in yet: [NotificationService] works without
/// one, so the game code can already call it.
abstract class NotificationBackend {
  Future<void> init();

  /// Shows a notification now.
  Future<void> show(NotificationKind kind, {required String title, required String body, String? payload});

  /// Schedules the daily reminder at [hour]:[minute] local time.
  Future<void> scheduleDaily(NotificationKind kind, {required int hour, required int minute, required String title, required String body});

  Future<void> cancel(NotificationKind kind);
}

/// The one place the game asks for notifications. Without a backend (web,
/// desktop, tests) every call does nothing.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  NotificationBackend? _backend;

  /// Whether the player allows notifications (set from the settings).
  bool enabled = true;

  /// The last notifications asked for; used by tests and a future inbox.
  @visibleForTesting
  final List<NotificationKind> asked = <NotificationKind>[];

  bool get available => _backend != null;

  Future<void> attach(NotificationBackend backend) async {
    _backend = backend;
    try {
      await backend.init();
    } catch (_) {
      _backend = null;
    }
  }

  void detach() => _backend = null;

  /// Somebody invited the player to a table.
  Future<void> invite({required String from, required String code, required String title, required String body}) =>
      _show(NotificationKind.invite, title, body, 'room:$code');

  /// Somebody sent the player a friend request.
  Future<void> friendRequest({required String from, required String title, required String body}) =>
      _show(NotificationKind.friendRequest, title, body, 'friends');

  /// Reminds about the daily quests every day at [hour]:[minute].
  Future<void> scheduleQuestReminder({required String title, required String body, int hour = 19, int minute = 0}) async {
    if (!enabled) return;
    asked.add(NotificationKind.dailyQuests);
    try {
      await _backend?.scheduleDaily(NotificationKind.dailyQuests, hour: hour, minute: minute, title: title, body: body);
    } catch (_) {}
  }

  Future<void> cancelQuestReminder() async {
    try {
      await _backend?.cancel(NotificationKind.dailyQuests);
    } catch (_) {}
  }

  Future<void> _show(NotificationKind kind, String title, String body, String payload) async {
    if (!enabled) return;
    asked.add(kind);
    try {
      await _backend?.show(kind, title: title, body: body, payload: payload);
    } catch (_) {}
  }
}
