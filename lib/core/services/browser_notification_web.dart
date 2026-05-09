// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

class BrowserNotification {
  static bool _permissionAsked = false;
  static const String _notificationIconPath = 'assets/assets/images/logo.png';
  static const String _seenStorageKey = 'sccp_web_seen_notifications_v1';
  static const int _maxSeenEntries = 1800;

  static Future<void> ensurePermission() async {
    if (!html.Notification.supported) return;
    final current = html.Notification.permission;
    if (current == 'granted') return;
    if (current == 'denied') {
      _permissionAsked = true;
      return;
    }
    if (_permissionAsked) return;

    _permissionAsked = true;
    final next = await html.Notification.requestPermission();
    if (next == 'default') {
      // Si el navegador no permitió resolver permiso en ese intento,
      // habilita un nuevo intento posterior (por ejemplo tras interacción).
      _permissionAsked = false;
    }
  }

  static bool shouldNotify(
    String key, {
    Duration ttl = const Duration(hours: 24),
  }) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return true;

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final ttlMs = ttl.inMilliseconds;
      final map = _readSeenMap();

      map.removeWhere((_, value) => (nowMs - value) > ttlMs);
      if (map.containsKey(cleanKey)) {
        _writeSeenMap(map);
        return false;
      }

      map[cleanKey] = nowMs;
      _trimOldest(map, keep: _maxSeenEntries);
      _writeSeenMap(map);
      return true;
    } catch (_) {
      // En caso de fallo de storage, no bloquear notificación.
      return true;
    }
  }

  static Map<String, int> _readSeenMap() {
    final raw = html.window.localStorage[_seenStorageKey];
    if (raw == null || raw.trim().isEmpty) return <String, int>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, int>{};

    final result = <String, int>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value is int) {
        result[key] = value;
      } else if (value is num) {
        result[key] = value.toInt();
      } else {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) {
          result[key] = parsed;
        }
      }
    }
    return result;
  }

  static void _writeSeenMap(Map<String, int> map) {
    html.window.localStorage[_seenStorageKey] = jsonEncode(map);
  }

  static void _trimOldest(
    Map<String, int> map, {
    required int keep,
  }) {
    if (map.length <= keep) return;
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final removeCount = map.length - keep;
    for (int i = 0; i < removeCount; i++) {
      map.remove(entries[i].key);
    }
  }

  static void show({
    required String title,
    required String body,
  }) {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') return;

    html.Notification(
      title,
      body: body,
      icon: _notificationIconPath,
    );
  }
}
