class BrowserNotification {
  static Future<void> ensurePermission() async {}

  static bool shouldNotify(
    String key, {
    Duration ttl = const Duration(hours: 24),
  }) {
    return true;
  }

  static void show({
    required String title,
    required String body,
  }) {}
}
