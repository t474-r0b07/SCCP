// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'dtex_geo_position.dart';

Future<DtexGeoPosition?> getCurrentDtexPosition() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: const Duration(seconds: 5),
    );
    final coords = position.coords;
    if (coords == null || coords.latitude == null || coords.longitude == null) {
      return null;
    }
    return DtexGeoPosition(
      latitude: coords.latitude!.toDouble(),
      longitude: coords.longitude!.toDouble(),
      accuracy: coords.accuracy?.toDouble(),
      speed: coords.speed?.toDouble(),
      heading: coords.heading?.toDouble(),
      altitude: coords.altitude?.toDouble(),
      isMocked: false,
    );
  } catch (_) {
    return null;
  }
}
