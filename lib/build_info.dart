/// What kind of build this is, set when building:
///
///     flutter build web --dart-define=PASTRA_CHANNEL=preview --dart-define=PASTRA_COMMIT=abc1234
///
/// The live site (and every app build) is `live`; the preview site of the
/// `ui-v2` branch (https://…/Pastra/preview/) is `preview`.
class BuildInfo {
  BuildInfo._();

  static const String channel = String.fromEnvironment('PASTRA_CHANNEL', defaultValue: 'live');

  /// The commit the build was made from (short hash; empty when unknown).
  static const String commit = String.fromEnvironment('PASTRA_COMMIT');

  static bool get preview => channel == 'preview';
}
