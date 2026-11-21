/// Crash reports from the Android and iOS apps (Firebase Crashlytics).
///
/// [startCrashReports] is called once at start-up. On Android and iOS it
/// starts Firebase and sends what went wrong: crashes of the app itself (the
/// native part reports them by itself) and errors in the game's code
/// (reported as non-fatal: the game keeps running). Nothing is sent from
/// debug builds, and no name or player id goes with a report, only the
/// build (`BuildInfo.channel` and `BuildInfo.commit`).
///
/// The web and Windows builds have no crash reports (Crashlytics does not
/// run there); the web build does not even contain the package.
library;

export 'crash_reports_stub.dart' if (dart.library.io) 'crash_reports_io.dart';
