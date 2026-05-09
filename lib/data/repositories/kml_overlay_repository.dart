import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../models/kml_overlay_data.dart';

class KmlOverlayRepository {
  static final List<Color> _palette = [
    AppConstants.neonCyan,
    AppConstants.neonPink,
    AppConstants.neonOrange,
    AppConstants.neonGreen,
  ];

  Future<KmlOverlayData> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return parse(raw);
  }

  KmlOverlayData parse(String kml) {
    final styleById = _parseStyles(kml);
    final styleMapById = _parseStyleMaps(kml);

    final placemarkRegex =
        RegExp(r'<Placemark\b[^>]*>(.*?)</Placemark>', dotAll: true);
    final nameRegex = RegExp(r'<name>(.*?)</name>', dotAll: true);
    final descriptionRegex = RegExp(r'<description>(.*?)</description>', dotAll: true);
    final styleUrlRegex = RegExp(r'<styleUrl>(.*?)</styleUrl>', dotAll: true);
    final pointRegex = RegExp(
        r'<Point\b[^>]*>.*?<coordinates>(.*?)</coordinates>.*?</Point>',
        dotAll: true);
    final lineRegex = RegExp(
        r'<LineString\b[^>]*>.*?<coordinates>(.*?)</coordinates>.*?</LineString>',
        dotAll: true);
    final polygonRegex = RegExp(
        r'<Polygon\b[^>]*>.*?<outerBoundaryIs>.*?<LinearRing>.*?<coordinates>(.*?)</coordinates>.*?</LinearRing>.*?</outerBoundaryIs>.*?</Polygon>',
        dotAll: true);

    final polygons = <KmlZonePolygon>[];
    final polylines = <KmlZonePolyline>[];
    final commandPointsByKey = <String, KmlCommandPoint>{};

    int colorIndex = 0;
    for (final match in placemarkRegex.allMatches(kml)) {
      final block = match.group(1) ?? '';
      final nameMatch = nameRegex.firstMatch(block);
      final name = _clean(nameMatch?.group(1) ?? 'SIN NOMBRE');
      final description = _clean(descriptionRegex.firstMatch(block)?.group(1) ?? '');
      final fallbackColor = _palette[colorIndex % _palette.length];
      colorIndex++;
      final styleUrlRaw = _clean(styleUrlRegex.firstMatch(block)?.group(1) ?? '');
      final resolvedStyleId = _resolveStyleId(styleUrlRaw, styleMapById);
      final style = styleById[resolvedStyleId];

      final polygonMatch = polygonRegex.firstMatch(block);
      if (polygonMatch != null) {
        final coords = _parseCoordsList(polygonMatch.group(1) ?? '');
        if (coords.length >= 3) {
          final color =
              style?.polyColor ?? style?.lineColor ?? style?.iconColor ?? fallbackColor;
          polygons.add(
            KmlZonePolygon(name: name, points: coords, color: color),
          );
          final polygonBaseName = _baseNameFromZone(name);
          if (_isCommandName(polygonBaseName)) {
            final key = _normalizeForMatch(polygonBaseName);
            commandPointsByKey.putIfAbsent(
              key,
              () => KmlCommandPoint(
                name: polygonBaseName,
                point: _centroid(coords),
                color: color,
              ),
            );
          }
        }
      }

      final lineMatch = lineRegex.firstMatch(block);
      if (lineMatch != null) {
        final coords = _parseCoordsList(lineMatch.group(1) ?? '');
        if (coords.length >= 2) {
          final color =
              style?.lineColor ?? style?.polyColor ?? style?.iconColor ?? fallbackColor;
          polylines.add(
            KmlZonePolyline(name: name, points: coords, color: color),
          );
          final lineLabelSource = description.isNotEmpty ? description : name;
          final lineBaseName = _baseNameFromZone(lineLabelSource);
          if (_isCommandName(lineBaseName)) {
            final key = _normalizeForMatch(lineBaseName);
            commandPointsByKey.putIfAbsent(
              key,
              () => KmlCommandPoint(
                name: lineBaseName,
                point: _centroid(coords),
                color: color,
              ),
            );
          }
        }
      }

      final pointMatch = pointRegex.firstMatch(block);
      if (pointMatch != null) {
        final points = _parseCoordsList(pointMatch.group(1) ?? '');
        if (points.isNotEmpty) {
          final isCommand = _isCommandName(name);
          if (isCommand) {
            final color =
                style?.iconColor ?? style?.lineColor ?? style?.polyColor ?? fallbackColor;
            final key = _normalizeForMatch(name);
            commandPointsByKey[key] = KmlCommandPoint(
              name: _baseNameFromZone(name),
              point: points.first,
              color: color,
            );
          }
        }
      }
    }

    return KmlOverlayData(
      polygons: polygons,
      polylines: polylines,
      commandPoints: commandPointsByKey.values.toList(),
    );
  }

  List<LatLng> _parseCoordsList(String raw) {
    final coords = <LatLng>[];
    final tokens = raw.replaceAll('\n', ' ').split(RegExp(r'\s+'));
    for (final token in tokens) {
      if (token.trim().isEmpty) continue;
      final parts = token.split(',');
      if (parts.length < 2) continue;
      final lon = double.tryParse(parts[0].trim());
      final lat = double.tryParse(parts[1].trim());
      if (lat == null || lon == null) continue;
      coords.add(LatLng(lat, lon));
    }
    return coords;
  }

  Map<String, _KmlStyle> _parseStyles(String kml) {
    final styleRegex = RegExp(r'<Style\b[^>]*id="([^"]+)"[^>]*>(.*?)</Style>',
        dotAll: true);
    final lineColorRegex =
        RegExp(r'<LineStyle\b[^>]*>.*?<color>([0-9a-fA-F]{8})</color>.*?</LineStyle>',
            dotAll: true);
    final polyColorRegex =
        RegExp(r'<PolyStyle\b[^>]*>.*?<color>([0-9a-fA-F]{8})</color>.*?</PolyStyle>',
            dotAll: true);
    final iconColorRegex =
        RegExp(r'<IconStyle\b[^>]*>.*?<color>([0-9a-fA-F]{8})</color>.*?</IconStyle>',
            dotAll: true);

    final map = <String, _KmlStyle>{};
    for (final m in styleRegex.allMatches(kml)) {
      final id = m.group(1) ?? '';
      final block = m.group(2) ?? '';
      map[id] = _KmlStyle(
        lineColor: _parseKmlColor(lineColorRegex.firstMatch(block)?.group(1)),
        polyColor: _parseKmlColor(polyColorRegex.firstMatch(block)?.group(1)),
        iconColor: _parseKmlColor(iconColorRegex.firstMatch(block)?.group(1)),
      );
    }
    return map;
  }

  Map<String, String> _parseStyleMaps(String kml) {
    final styleMapRegex = RegExp(
        r'<StyleMap\b[^>]*id="([^"]+)"[^>]*>(.*?)</StyleMap>',
        dotAll: true);
    final normalPairRegex = RegExp(
        r'<Pair>\s*<key>\s*normal\s*</key>\s*<styleUrl>\s*#?([^<\s]+)\s*</styleUrl>\s*</Pair>',
        dotAll: true);

    final map = <String, String>{};
    for (final m in styleMapRegex.allMatches(kml)) {
      final id = m.group(1) ?? '';
      final block = m.group(2) ?? '';
      final normalTarget = normalPairRegex.firstMatch(block)?.group(1);
      if (id.isNotEmpty && normalTarget != null && normalTarget.isNotEmpty) {
        map[id] = normalTarget;
      }
    }
    return map;
  }

  String _resolveStyleId(String styleUrl, Map<String, String> styleMapById) {
    if (styleUrl.isEmpty) return '';
    final id = styleUrl.startsWith('#') ? styleUrl.substring(1) : styleUrl;
    return styleMapById[id] ?? id;
  }

  Color? _parseKmlColor(String? value) {
    if (value == null) return null;
    final v = value.trim();
    if (v.length != 8) return null;
    final a = int.tryParse(v.substring(0, 2), radix: 16);
    final b = int.tryParse(v.substring(2, 4), radix: 16);
    final g = int.tryParse(v.substring(4, 6), radix: 16);
    final r = int.tryParse(v.substring(6, 8), radix: 16);
    if ([a, b, g, r].any((e) => e == null)) return null;
    return Color.fromARGB(a!, r!, g!, b!);
  }

  bool _isCommandName(String name) {
    final n = _normalizeForMatch(name);
    return n.contains('EPI') ||
        n.contains('MODULO') ||
        n.contains('POLICIAL') ||
        n.contains('COMANDO') ||
        n.contains('ESTACION') ||
        n.contains('BASE');
  }

  String _baseNameFromZone(String input) {
    final n = _clean(input);
    final cleaned = n
        // Handles both "JURISDICCION" and "JURISDICION", with optional "DE/DEL/DE LA"
        .replaceFirst(
          RegExp(r'^JURISDIC+C?ION(?:\s+DE(?:\s+LA|\s+L)?|\s+DEL)?\s+',
              caseSensitive: false),
          '',
        )
        .trim();
    return cleaned.isEmpty ? n : cleaned;
  }

  String _normalizeForMatch(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  LatLng _centroid(List<LatLng> points) {
    final lat = points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((e) => e.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  String _clean(String input) {
    return input
        .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _KmlStyle {
  final Color? lineColor;
  final Color? polyColor;
  final Color? iconColor;

  const _KmlStyle({
    this.lineColor,
    this.polyColor,
    this.iconColor,
  });
}
