import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../data/models/kml_overlay_data.dart';
import '../../data/models/monitoreo_reporte_model.dart';
import '../../data/models/oficial_model.dart';
import '../../data/repositories/kml_overlay_repository.dart';
import '../controllers/dashboard_controller.dart';
import 'detallado_perfil_oficial_dialog.dart';

enum _AlertKind { none, abandono, inconsistencia, parteNovedad }

class TacticalMap extends StatefulWidget {
  const TacticalMap({super.key});

  @override
  State<TacticalMap> createState() => _TacticalMapState();
}

class _TacticalMapState extends State<TacticalMap> {
  final MapController _mapController = MapController();
  final MapController _fullscreenMapController = MapController();
  final Distance _distance = const Distance();
  final KmlOverlayRepository _kmlRepository = KmlOverlayRepository();

  KmlOverlayData _kmlOverlay = KmlOverlayData.empty;
  bool _showJurisdictionLayer = true;
  bool _showPoiLayer = false;
  bool _showMapInfoPanels = true;
  bool _mapInfoPanelsInitialized = false;
  static const List<({String name, double lat, double lng})> _manualBases = [
    (name: 'EPI MORROS BLANCOS', lat: -21.5483132, lng: -64.6989562),
    (name: 'EPI CENTRAL', lat: -21.5336997, lng: -64.7355013),
    (name: 'EPI SENAC', lat: -21.5421969, lng: -64.7466267),
    (name: 'EPI MOTO MENDEZ', lat: -21.5348671, lng: -64.7114756),
    (name: 'EPI LOURDES', lat: -21.5135712, lng: -64.7275175),
    (name: 'EPI CHAPACOS', lat: -21.5123465, lng: -64.7408198),
    (name: 'FELCV', lat: -21.5321591, lng: -64.7410211),
    (name: 'FELCC', lat: -21.5293946, lng: -64.7305313),
    (name: 'COMANDO DPTAL.', lat: -21.5340340, lng: -64.7375050),
    (name: 'PAC', lat: -21.5186664, lng: -64.7364318),
    (name: 'BOMBEROS', lat: -21.5475722, lng: -64.7016750),
    (name: 'TRANSITO', lat: -21.5307549, lng: -64.7416813),
    (name: 'DELTA', lat: -21.5262105, lng: -64.7292879),
    (name: 'DIPROVE', lat: -21.5349580, lng: -64.7123274),
  ];
  static const List<({String name, String category, double lat, double lng})>
      _referencePois = [
    (
      name: 'Mercado Central',
      category: 'TIENDA',
      lat: -21.53315,
      lng: -64.73285
    ),
    (
      name: 'Farmacia Lourdes',
      category: 'FARMACIA',
      lat: -21.51455,
      lng: -64.72945
    ),
    (
      name: 'Banco Principal',
      category: 'BANCO',
      lat: -21.53122,
      lng: -64.73610
    ),
    (
      name: 'Estación de Servicio Sur',
      category: 'SERVICIO',
      lat: -21.54685,
      lng: -64.70240
    ),
    (
      name: 'Terminal Local',
      category: 'REFERENCIA',
      lat: -21.53545,
      lng: -64.72870
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadKmlOverlay();
  }

  Future<void> _loadKmlOverlay() async {
    try {
      final loaded = await _kmlRepository.loadFromAsset(
        'assets/maps/jurisdicciones_epis_full.kml',
      );
      if (!mounted) return;
      setState(() {
        _kmlOverlay = loaded;
      });
    } catch (_) {
      // If KML fails to load, map remains functional without that layer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    if (!_mapInfoPanelsInitialized) {
      // Operativo: mantener paneles de mapa visibles por defecto.
      _showMapInfoPanels = true;
      _mapInfoPanelsInitialized = true;
    }
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.darkBg,
        border:
            Border.all(color: AppConstants.neonCyan.withValues(alpha: 0.45)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF020812), Color(0xFF06111F)],
                ),
              ),
            ),
          ),
          Obx(() {
            final entries = _buildEntries(controller);
            if (entries.isEmpty) {
              return _buildEmptyState();
            }
            final reoControlPoints = _buildControlPoints(controller);
            final center =
                _center(entries.map((e) => e.officerPosition).toList());
            final recentAlerts = _recentAlerts(entries);

            return Stack(
              children: [
                _buildInteractiveMap(
                  mapController: _mapController,
                  entries: entries,
                  reoControlPoints: reoControlPoints,
                  initialCenter: center,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen,
                        color: AppConstants.neonCyan),
                    onPressed: () => _openFullscreen(
                      entries: entries,
                      reoControlPoints: reoControlPoints,
                      center: center,
                      alerts: recentAlerts,
                    ),
                  ),
                ),
                Positioned(
                  top: 44,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong,
                        color: AppConstants.neonCyan),
                    onPressed: () => _mapController.move(center, 14.6),
                  ),
                ),
                Positioned(
                  top: 78,
                  left: 10,
                  child: IconButton(
                    icon: Icon(
                      _showJurisdictionLayer
                          ? Icons.layers
                          : Icons.layers_clear,
                      color: _showJurisdictionLayer
                          ? AppConstants.neonCyan
                          : Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _showJurisdictionLayer = !_showJurisdictionLayer;
                      });
                    },
                  ),
                ),
                Positioned(
                  top: 112,
                  left: 10,
                  child: IconButton(
                    icon: Icon(
                      _showPoiLayer
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                      color:
                          _showPoiLayer ? Colors.amberAccent : Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPoiLayer = !_showPoiLayer;
                      });
                    },
                  ),
                ),
                Positioned(
                  top: 146,
                  left: 10,
                  child: IconButton(
                    tooltip: _showMapInfoPanels
                        ? 'Ocultar paneles del mapa'
                        : 'Mostrar paneles del mapa',
                    icon: Icon(
                      _showMapInfoPanels
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: _showMapInfoPanels
                          ? Colors.white70
                          : AppConstants.neonCyan,
                    ),
                    onPressed: () {
                      setState(() {
                        _showMapInfoPanels = !_showMapInfoPanels;
                      });
                    },
                  ),
                ),
                // Panel de alertas deshabilitado por requerimiento operativo.
                const Positioned(
                  top: 66,
                  right: 10,
                  child: SizedBox.shrink(),
                ),
                if (_showMapInfoPanels &&
                    _showJurisdictionLayer &&
                    _kmlOverlay.polygons.isNotEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _ZoneLegend(polygons: _kmlOverlay.polygons),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'SIN REPORTES DEL TURNO',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  List<_MapEntry> _buildEntries(DashboardController controller) {
    final map = <String, MonitoreoReporte>{};
    final operationalWindow = _currentOperationalWindow();
    final group = controller.currentGroup.value.toUpperCase();
    final officialById = <String, Oficial>{
      for (final o in controller.oficiales) o.idOficial: o,
    };

    for (final report in controller.reportes) {
      final local = report.fechaHora;
      if (local.isBefore(operationalWindow.start) ||
          !local.isBefore(operationalWindow.end)) {
        continue;
      }
      final reportGroup = (report.grupo ?? '').toString().trim().toUpperCase();
      final officialGroup =
          (officialById[report.idOficialRef]?.grupo ?? '').trim().toUpperCase();
      final resolvedGroup =
          reportGroup.isNotEmpty ? reportGroup : officialGroup;
      if (resolvedGroup.isNotEmpty && resolvedGroup != group) {
        continue;
      }
      final prev = map[report.idOficialRef];
      if (prev == null || report.fechaHora.isAfter(prev.fechaHora)) {
        map[report.idOficialRef] = report;
      }
    }

    final rawEntries = map.values.map((report) {
      final oficial = controller.oficiales
          .firstWhereOrNull((o) => o.idOficial == report.idOficialRef);
      final officerPosition = _normalizeLatLng(
        report.latitud ?? AppConstants.defaultLatitude,
        report.longitud ?? AppConstants.defaultLongitude,
      );
      final reo = controller.findReoByCodigo(report.reoAsignado) ??
          controller.findReoByOficial(oficial?.idOficial);
      final parsed = controller.parseCoords(reo?.coordenadasCasa);
      final reoPosition = parsed == null
          ? _normalizeLatLng(
              (report.latitud ?? AppConstants.defaultLatitude) + 0.00022,
              (report.longitud ?? AppConstants.defaultLongitude) + 0.00022,
            )
          : _normalizeLatLng(parsed.lat, parsed.lng);
      final meters = report.distanciaMetros ??
          _distance.as(LengthUnit.Meter, officerPosition, reoPosition);
      final kind = _alertKind(report, meters);
      final color = _alertColor(kind);
      final reoLabel = reo?.nombreCompleto ??
          controller.getReoNombreByCodigo(report.reoAsignado);

      return _MapEntry(
        report: report,
        oficial: oficial,
        officerPosition: officerPosition,
        reoPosition: reoPosition,
        meters: meters,
        kind: kind,
        color: color,
        reoLabel: reoLabel,
      );
    }).toList();

    return _spreadOfficerPositions(rawEntries);
  }

  ({DateTime start, DateTime end}) _currentOperationalWindow() {
    final now = DateTime.now();
    final anchor = now.hour < 8 ? now.subtract(const Duration(days: 1)) : now;
    final start = DateTime(anchor.year, anchor.month, anchor.day, 8, 0, 0);
    final end = start.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  List<_MapEntry> _spreadOfficerPositions(List<_MapEntry> entries) {
    if (entries.length <= 1) return entries;

    final buckets = <String, List<int>>{};
    for (int i = 0; i < entries.length; i++) {
      final p = entries[i].officerPosition;
      // Bucket de ~11m para detectar oficiales superpuestos en mapa.
      final key =
          '${(p.latitude * 10000).round()}_${(p.longitude * 10000).round()}';
      buckets.putIfAbsent(key, () => <int>[]).add(i);
    }

    final adjusted = List<_MapEntry>.from(entries);
    for (final indices in buckets.values) {
      if (indices.length <= 1) continue;
      for (int i = 0; i < indices.length; i++) {
        final idx = indices[i];
        final base = entries[idx].officerPosition;
        final angle = (2 * math.pi * i) / indices.length;
        final radiusMeters = indices.length >= 4 ? 8.0 : 6.0;
        final latOffset = _metersToLat(radiusMeters * math.sin(angle));
        final lngOffset = _metersToLng(
          radiusMeters * math.cos(angle),
          base.latitude,
        );
        final shifted = _normalizeLatLng(
          base.latitude + latOffset,
          base.longitude + lngOffset,
        );
        adjusted[idx] = entries[idx].copyWith(officerPosition: shifted);
      }
    }
    return adjusted;
  }

  double _metersToLat(double meters) => meters / 111111.0;

  double _metersToLng(double meters, double atLatitude) {
    final cosLat = math.cos(atLatitude * (math.pi / 180)).abs();
    final safeCos = cosLat < 0.2 ? 0.2 : cosLat;
    return meters / (111111.0 * safeCos);
  }

  List<_ControlPoint> _buildControlPoints(DashboardController controller) {
    final points = <_ControlPoint>[];
    final entries = _buildEntries(controller);
    for (final e in entries) {
      points.add(
        _ControlPoint(
          position: e.reoPosition,
          label: e.reoLabel,
        ),
      );
    }
    return points;
  }

  Widget _buildInteractiveMap({
    required MapController mapController,
    required List<_MapEntry> entries,
    required List<_ControlPoint> reoControlPoints,
    required LatLng initialCenter,
  }) {
    final commandPoints = _mergedCommandPoints();
    final poiPoints = _referencePois
        .map(
          (p) => _MapPoi(
            name: p.name,
            category: p.category,
            point: _normalizeLatLng(p.lat, p.lng),
          ),
        )
        .toList();
    final jurisdictionPolygons = <Polygon>[
      if (_showJurisdictionLayer)
        for (final zone in _kmlOverlay.polygons)
          Polygon(
            points: zone.points,
            color: zone.color.withValues(alpha: 0.30),
            borderColor: zone.color.withValues(alpha: 0.70),
            borderStrokeWidth: 1.1,
          ),
    ];

    final jurisdictionLines = <Polyline>[
      if (_showJurisdictionLayer)
        for (final line in _kmlOverlay.polylines)
          Polyline(
            points: line.points,
            color: line.color.withValues(alpha: 0.70),
            strokeWidth: 1.2,
          ),
    ];

    final circles = <CircleMarker>[
      for (final p in reoControlPoints)
        CircleMarker(
          point: p.position,
          radius: 50,
          useRadiusInMeter: true,
          color: Colors.orangeAccent.withValues(alpha: 0.07),
          borderStrokeWidth: 1.1,
          borderColor: Colors.orangeAccent.withValues(alpha: 0.7),
        ),
    ];

    final lines = <Polyline>[
      ...jurisdictionLines,
      for (final e in entries)
        Polyline(
          points: [e.officerPosition, e.reoPosition],
          color: e.kind == _AlertKind.none ? _distanceColor(e.meters) : e.color,
          strokeWidth: e.meters > 50 ? 2.2 : 1.6,
        ),
    ];

    final markers = <Marker>[
      if (_showJurisdictionLayer)
        for (final cmd in commandPoints)
          Marker(
            point: cmd.point,
            width: _isMobileViewport(context) ? 136 : 170,
            height: _isMobileViewport(context) ? 24 : 28,
            child: Tooltip(
              message: cmd.name,
              waitDuration: const Duration(milliseconds: 120),
              child: Builder(builder: (context) {
                final mobile = _isMobileViewport(context);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: mobile ? 18 : 22,
                      height: mobile ? 18 : 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amberAccent.withValues(alpha: 0.20),
                        border: Border.all(
                          color: AppConstants.neonGreen.withValues(alpha: 0.95),
                          width: mobile ? 1.0 : 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: Colors.amberAccent,
                        size: mobile ? 11 : 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 4 : 6,
                          vertical: mobile ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color:
                                AppConstants.neonGreen.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          cmd.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.amberAccent.withValues(alpha: 0.95),
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            fontSize: mobile ? 8.5 : 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
      for (final p in reoControlPoints)
        Marker(
          point: p.position,
          width: 34,
          height: 34,
          child: Tooltip(
            message: 'Punto de control: ${p.label}',
            waitDuration: const Duration(milliseconds: 120),
            child: const _ReoMarker(color: Colors.orangeAccent),
          ),
        ),
      for (final e in entries)
        Marker(
          point: e.officerPosition,
          width: 50,
          height: 50,
          child: Tooltip(
            message: e.oficial?.nombreOficial ?? 'Oficial',
            waitDuration: const Duration(milliseconds: 120),
            child: GestureDetector(
              onTap: e.oficial == null
                  ? null
                  : () => Get.dialog(
                        DetalladoPerfilOficialDialog(
                          oficial: e.oficial!,
                          controller: Get.find<DashboardController>(),
                        ),
                      ),
              child: _OfficerMarker(
                hasAlert: e.kind != _AlertKind.none,
                color: e.kind == _AlertKind.none
                    ? AppConstants.successGreen
                    : e.color,
              ),
            ),
          ),
        ),
      if (_showPoiLayer)
        for (final poi in poiPoints)
          Marker(
            point: poi.point,
            width: 130,
            height: 24,
            child: Tooltip(
              message: '${poi.name} (${poi.category})',
              waitDuration: const Duration(milliseconds: 120),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.95),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.place_rounded,
                      color: Colors.amberAccent,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      poi.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.95),
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 13.0,
        interactionOptions: InteractionOptions(
          flags: _mapInteractionFlags(context),
        ),
        onMapReady: () {
          final allPoints = <LatLng>[
            ...entries.map((e) => e.officerPosition),
            ...entries.map((e) => e.reoPosition),
            ...reoControlPoints.map((e) => e.position),
            if (_showJurisdictionLayer) ...commandPoints.map((e) => e.point),
            if (_showPoiLayer) ...poiPoints.map((e) => e.point),
          ];
          if (allPoints.length >= 2) {
            mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: allPoints,
                padding: const EdgeInsets.all(52),
              ),
            );
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: true,
          userAgentPackageName: 'sccp_command_center',
        ),
        if (jurisdictionPolygons.isNotEmpty)
          PolygonLayer(polygons: jurisdictionPolygons),
        CircleLayer(circles: circles),
        PolylineLayer(polylines: lines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  int _mapInteractionFlags(BuildContext context) {
    final mobileViewport = _isMobileViewport(context);
    if (!mobileViewport) return InteractiveFlag.all;
    // En móvil: permitir arrastre + zoom, sin rotación.
    return InteractiveFlag.all & ~InteractiveFlag.rotate;
  }

  bool _isMobileViewport(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width < 980 || media.size.shortestSide < 700;
  }

  List<KmlCommandPoint> _mergedCommandPoints() {
    final merged = <String, KmlCommandPoint>{};
    for (final cmd in _kmlOverlay.commandPoints) {
      merged[_normalizeName(cmd.name)] = cmd;
    }
    for (final b in _manualBases) {
      final key = _normalizeName(b.name);
      merged[key] = KmlCommandPoint(
        name: b.name,
        point: _normalizeLatLng(b.lat, b.lng),
        color: AppConstants.neonGreen,
      );
    }
    return merged.values.toList();
  }

  String _normalizeName(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  LatLng _normalizeLatLng(double lat, double lng) {
    if (_isBoliviaLike(lat, lng)) return LatLng(lat, lng);
    if (_isBoliviaLike(lng, lat)) return LatLng(lng, lat);
    return LatLng(lat, lng);
  }

  bool _isBoliviaLike(double lat, double lng) {
    return lat >= -25.0 && lat <= -8.0 && lng >= -70.5 && lng <= -57.0;
  }

  void _openFullscreen({
    required List<_MapEntry> entries,
    required List<_ControlPoint> reoControlPoints,
    required LatLng center,
    required List<_AlertFeedEntry> alerts,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              color: AppConstants.darkBg,
              border: Border.all(
                  color: AppConstants.neonCyan.withValues(alpha: 0.45)),
            ),
            child: Stack(
              children: [
                _buildInteractiveMap(
                  mapController: _fullscreenMapController,
                  entries: entries,
                  reoControlPoints: reoControlPoints,
                  initialCenter: center,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.fullscreen_exit,
                        color: AppConstants.neonCyan),
                    onPressed: () => Get.back(),
                  ),
                ),
                Positioned(
                  top: 42,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong,
                        color: AppConstants.neonCyan),
                    onPressed: () => _fullscreenMapController.move(center, 15),
                  ),
                ),
                Positioned(
                  top: 76,
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      _showPoiLayer
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                      color:
                          _showPoiLayer ? Colors.amberAccent : Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPoiLayer = !_showPoiLayer;
                      });
                    },
                  ),
                ),
                Positioned(
                  top: 110,
                  left: 8,
                  child: IconButton(
                    tooltip: _showMapInfoPanels
                        ? 'Ocultar paneles del mapa'
                        : 'Mostrar paneles del mapa',
                    icon: Icon(
                      _showMapInfoPanels
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: _showMapInfoPanels
                          ? Colors.white70
                          : AppConstants.neonCyan,
                    ),
                    onPressed: () {
                      setState(() {
                        _showMapInfoPanels = !_showMapInfoPanels;
                      });
                    },
                  ),
                ),
                // Panel de alertas deshabilitado por requerimiento operativo.
                const Positioned(
                  top: 66,
                  right: 10,
                  child: SizedBox.shrink(),
                ),
                if (_showMapInfoPanels &&
                    _showJurisdictionLayer &&
                    _kmlOverlay.polygons.isNotEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _ZoneLegend(polygons: _kmlOverlay.polygons),
                  ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  LatLng _center(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(
          AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    }
    final lat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((e) => e.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  _AlertKind _alertKind(MonitoreoReporte report, double meters) {
    final prioridad = (report.prioridad ?? '').toUpperCase();
    final estado = report.estadoAlerta.toUpperCase();
    final parte = (report.parteNovedad ?? '').trim().toUpperCase();

    if (parte.isNotEmpty && parte != 'NINGUNA' && parte != 'SIN NOVEDAD') {
      return _AlertKind.parteNovedad;
    }
    if (prioridad.contains('INCONS') || estado == 'ALERTA') {
      return _AlertKind.inconsistencia;
    }
    if (meters > 50 || estado == 'CRITICO' || prioridad.contains('ABANDONO')) {
      return _AlertKind.abandono;
    }
    return _AlertKind.none;
  }

  Color _alertColor(_AlertKind kind) {
    switch (kind) {
      case _AlertKind.abandono:
        return Colors.redAccent;
      case _AlertKind.inconsistencia:
        return const Color(0xFF8A2BE2);
      case _AlertKind.parteNovedad:
        return const Color(0xFFFF00AA);
      case _AlertKind.none:
        return AppConstants.neonCyan;
    }
  }

  Color _distanceColor(double meters) {
    if (meters <= 50) return AppConstants.successGreen;
    if (meters <= 100) return AppConstants.alertOrange;
    return AppConstants.warningRed;
  }

  List<_AlertFeedEntry> _recentAlerts(List<_MapEntry> entries) {
    final alerts = entries
        .where((e) => e.kind != _AlertKind.none)
        .map(
          (e) => _AlertFeedEntry(
            oficialNombre: e.oficial?.nombreOficial ??
                e.report.nombreOficial ??
                'OFICIAL N/D',
            label: _labelByKind(e.kind),
            motivo: _reasonFromEntry(e),
            distanceMeters: e.meters,
            color: _alertColor(e.kind),
            time: e.report.fechaHora,
          ),
        )
        .toList();
    alerts.sort((a, b) => b.time.compareTo(a.time));
    return alerts.take(6).toList();
  }

  String _labelByKind(_AlertKind kind) {
    switch (kind) {
      case _AlertKind.abandono:
        return 'ABANDONO';
      case _AlertKind.inconsistencia:
        return 'INCONSISTENCIA';
      case _AlertKind.parteNovedad:
        return 'PARTE/NOVEDAD';
      case _AlertKind.none:
        return 'NORMAL';
    }
  }

  String _reasonFromEntry(_MapEntry entry) {
    final estado = entry.report.estadoAlerta.toUpperCase();
    final parte = (entry.report.parteNovedad ?? '').trim().toUpperCase();
    final battery = (entry.report.nivelBateria ?? 100).toDouble();

    if (parte.isNotEmpty && parte != 'NINGUNA' && parte != 'SIN NOVEDAD') {
      return 'PARTE/NOVEDAD';
    }
    if (entry.meters > 50) {
      return 'FUERA DE RANGO';
    }
    if (!entry.report.gpsReal) {
      return 'GPS NO CONFIABLE';
    }
    if (battery < 20) {
      return 'BATERIA BAJA';
    }
    if (estado == 'CRITICO') {
      return 'ALERTA CRITICA';
    }
    if (estado == 'ALERTA') {
      return 'ALERTA OPERATIVA';
    }
    return _labelByKind(entry.kind);
  }
}

class _MapEntry {
  final MonitoreoReporte report;
  final Oficial? oficial;
  final LatLng officerPosition;
  final LatLng reoPosition;
  final double meters;
  final _AlertKind kind;
  final Color color;
  final String reoLabel;

  const _MapEntry({
    required this.report,
    required this.oficial,
    required this.officerPosition,
    required this.reoPosition,
    required this.meters,
    required this.kind,
    required this.color,
    required this.reoLabel,
  });

  _MapEntry copyWith({
    LatLng? officerPosition,
  }) {
    return _MapEntry(
      report: report,
      oficial: oficial,
      officerPosition: officerPosition ?? this.officerPosition,
      reoPosition: reoPosition,
      meters: meters,
      kind: kind,
      color: color,
      reoLabel: reoLabel,
    );
  }
}

class _ControlPoint {
  final LatLng position;
  final String label;
  const _ControlPoint({required this.position, required this.label});
}

class _MapPoi {
  final String name;
  final String category;
  final LatLng point;

  const _MapPoi({
    required this.name,
    required this.category,
    required this.point,
  });
}

class _OfficerMarker extends StatefulWidget {
  final bool hasAlert;
  final Color color;
  const _OfficerMarker({required this.hasAlert, required this.color});

  @override
  State<_OfficerMarker> createState() => _OfficerMarkerState();
}

class _OfficerMarkerState extends State<_OfficerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.hasAlert ? 1 + (_controller.value * 0.3) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.24),
              border: Border.all(color: widget.color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.color
                      .withValues(alpha: widget.hasAlert ? 0.62 : 0.32),
                  blurRadius: widget.hasAlert ? 16 : 9,
                  spreadRadius: widget.hasAlert ? 3 : 1,
                ),
              ],
            ),
            child: const Center(
              child:
                  Icon(Icons.person_pin_circle, color: Colors.white, size: 22),
            ),
          ),
        );
      },
    );
  }
}

class _ReoMarker extends StatelessWidget {
  final Color color;
  const _ReoMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.24),
        border: Border.all(color: color, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.home_work_rounded, color: Colors.white, size: 16),
      ),
    );
  }
}

class _AlertFeedEntry {
  final String oficialNombre;
  final String label;
  final String motivo;
  final double distanceMeters;
  final Color color;
  final DateTime time;

  const _AlertFeedEntry({
    required this.oficialNombre,
    required this.label,
    required this.motivo,
    required this.distanceMeters,
    required this.color,
    required this.time,
  });
}

class _ZoneLegend extends StatelessWidget {
  final List<KmlZonePolygon> polygons;

  const _ZoneLegend({required this.polygons});

  @override
  Widget build(BuildContext context) {
    final unique = <String, KmlZonePolygon>{};
    for (final p in polygons) {
      unique.putIfAbsent(p.name, () => p);
    }
    final zones = unique.values.toList();

    return Container(
      width: 220,
      constraints: const BoxConstraints(maxHeight: 130),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JURISDICCION',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
              fontSize: 8,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: zones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 3),
              itemBuilder: (context, index) {
                final zone = zones[index];
                return Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: zone.color.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: zone.color.withValues(alpha: 0.95),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        zone.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
