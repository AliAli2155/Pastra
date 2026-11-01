# Notifications (infrastructure)

The game already calls `NotificationService` (lib/notifications/notification_service.dart):
friend requests call `friendRequest(...)`; `invite(...)` and `scheduleQuestReminder(...)` are ready
to be called. Without a backend every call does nothing (web, desktop, tests).

To switch notifications on for the Android app:

1. `flutter pub add flutter_local_notifications timezone flutter_timezone`
2. Implement `NotificationBackend` with that package (channel "Pastra", `zonedSchedule` with
   `matchDateTimeComponents: DateTimeComponents.time` for the daily quest reminder) and call
   `NotificationService.instance.attach(MyBackend())` in `main()` when `!kIsWeb`.
3. Android: enable core library desugaring in `android/app/build.gradle.kts`, add the
   `POST_NOTIFICATIONS` permission to `AndroidManifest.xml` and ask for it on Android 13+.
4. Push while the app is closed (invites, requests) needs Firebase Cloud Messaging plus a sender
   (Cloud Functions or the future VPS referee): store the FCM token under `users/<uid>/fcm` and
   send a message when `friendAdds/...` or an invitation is written.
