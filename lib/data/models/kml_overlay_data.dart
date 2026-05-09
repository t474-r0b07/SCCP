import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class KmlZonePolygon {
  final String name;
  final List<LatLng> points;
  final Color color;

  const KmlZonePolygon({
    required this.name,
    required this.points,
    required this.color,
  });
}

class KmlZonePolyline {
  final String name;
  final List<LatLng> points;
  final Color color;

  const KmlZonePolyline({
    required this.name,
    required this.points,
    required this.color,
  });
}

class KmlCommandPoint {
  final String name;
  final LatLng point;
  final Color color;

  const KmlCommandPoint({
    required this.name,
    required this.point,
    required this.color,
  });
}

class KmlOverlayData {
  final List<KmlZonePolygon> polygons;
  final List<KmlZonePolyline> polylines;
  final List<KmlCommandPoint> commandPoints;

  const KmlOverlayData({
    required this.polygons,
    required this.polylines,
    required this.commandPoints,
  });

  static const empty = KmlOverlayData(
    polygons: <KmlZonePolygon>[],
    polylines: <KmlZonePolyline>[],
    commandPoints: <KmlCommandPoint>[],
  );
}
