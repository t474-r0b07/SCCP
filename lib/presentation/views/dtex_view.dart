import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/dtex_tracking_extension_model.dart';
import '../controllers/dtex_controller.dart';

Future<void> showDtexDialog() async {
  final controller = Get.isRegistered<DtexController>()
      ? Get.find<DtexController>()
      : Get.put(DtexController());

  await Get.dialog<void>(
    DtexView(controller: controller),
    barrierDismissible: true,
  );
}

class DtexView extends StatefulWidget {
  final DtexController controller;

  const DtexView({
    super.key,
    required this.controller,
  });

  @override
  State<DtexView> createState() => _DtexViewState();
}

class _DtexViewState extends State<DtexView> {
  final _reoNombreController = TextEditingController();
  final _reoCiController = TextEditingController();
  final _expedienteController = TextEditingController();
  final _custodioNombreController = TextEditingController();
  final _custodioCodigoController = TextEditingController();
  final _custodioGradoController = TextEditingController();
  final _salidaEnMinController = TextEditingController(text: '15');
  final _tiempoMaxController = TextEditingController(text: '60');
  final _referenciaController = TextEditingController();
  final _notasController = TextEditingController();
  final _resolucionController = TextEditingController();

  String _tipoDiligencia = 'JUDICIAL';
  String _conductaFinal = DtexMision.conductaSinIncidencias;
  String? _destinoId;
  bool _showCreateForm = false;

  DtexController get controller => widget.controller;

  @override
  void dispose() {
    _reoNombreController.dispose();
    _reoCiController.dispose();
    _expedienteController.dispose();
    _custodioNombreController.dispose();
    _custodioCodigoController.dispose();
    _custodioGradoController.dispose();
    _salidaEnMinController.dispose();
    _tiempoMaxController.dispose();
    _referenciaController.dispose();
    _notasController.dispose();
    _resolucionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final mobile = media.width < 900 || media.shortestSide < 620;
    final width =
        mobile ? media.width : (media.width * 0.9).clamp(820.0, 1180.0);
    final height =
        mobile ? media.height : (media.height * 0.88).clamp(620.0, 820.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 0 : 18,
        vertical: mobile ? 0 : 18,
      ),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: width.toDouble(),
        height: height.toDouble(),
        child: SafeArea(
          top: mobile,
          bottom: mobile,
          child: Container(
            decoration: BoxDecoration(
              color: AppConstants.darkBg.withValues(alpha: 0.98),
              borderRadius:
                  mobile ? BorderRadius.zero : BorderRadius.circular(10),
              border: Border.all(
                color: AppConstants.neonCyan.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.neonCyan.withValues(alpha: 0.15),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(mobile),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 8 : 14,
                      10,
                      mobile ? 8 : 14,
                      mobile ? 8 : 14,
                    ),
                    child: mobile ? _buildMobileBody() : _buildDesktopBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool mobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 16,
        vertical: mobile ? 9 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppConstants.neonCyan.withValues(alpha: 0.28),
          ),
        ),
        gradient: LinearGradient(
          colors: [
            AppConstants.neonCyan.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
      ),
      child: Obx(
        () => Row(
          children: [
            Icon(
              Icons.route_rounded,
              color: AppConstants.neonCyan,
              size: mobile ? 20 : 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DTEX - DILIGENCIAS EXTERNAS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: mobile ? 11 : 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    controller.isConnected.value
                        ? 'Control de salida, destino, retorno y alertas'
                        : 'Conexion DTEX no disponible',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontFamily: 'Rajdhani',
                      fontSize: mobile ? 10 : 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!mobile) ...[
              _kpiChip('HOY', '${controller.totalMisionesHoy}',
                  AppConstants.neonCyan),
              const SizedBox(width: 6),
              _kpiChip('ACT', '${controller.totalMisionesActivas}',
                  AppConstants.successGreen),
              const SizedBox(width: 6),
              _kpiChip(
                'ALT',
                '${controller.totalAlertasPendientes}',
                controller.totalAlertasPendientes > 0
                    ? AppConstants.warningRed
                    : Colors.white54,
              ),
              const SizedBox(width: 6),
              _kpiChip(
                'EXT',
                '${controller.totalExtensiones}',
                controller.totalExtensiones > 0
                    ? AppConstants.alertOrange
                    : Colors.white54,
              ),
              const SizedBox(width: 10),
            ],
            IconButton(
              tooltip: 'Actualizar DTEX',
              onPressed: controller.loadInitialData,
              icon: const Icon(Icons.refresh_rounded),
              color: Colors.white70,
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Get.back(),
              icon: const Icon(Icons.close_rounded),
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildActionBar(),
              const SizedBox(height: 10),
              Expanded(child: _buildMissionList()),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              if (_showCreateForm) ...[
                Expanded(child: _buildCreateForm()),
              ] else ...[
                Expanded(child: _buildMissionDetail()),
                const SizedBox(height: 10),
                SizedBox(height: 190, child: _buildEventPanels()),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody() {
    return ListView(
      children: [
        _buildActionBar(),
        const SizedBox(height: 8),
        SizedBox(height: 300, child: _buildMissionList()),
        const SizedBox(height: 10),
        SizedBox(
          height: _showCreateForm ? 620 : 420,
          child: _showCreateForm ? _buildCreateForm() : _buildMissionDetail(),
        ),
        const SizedBox(height: 10),
        SizedBox(height: 230, child: _buildEventPanels()),
      ],
    );
  }

  Widget _buildActionBar() {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: DtexMision.estadosFiltrables
                  .map((estado) => _filterButton(estado))
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  _showCreateForm ? Colors.white24 : AppConstants.neonCyan,
              foregroundColor: _showCreateForm ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () => setState(() => _showCreateForm = !_showCreateForm),
            icon: Icon(
              _showCreateForm ? Icons.list_alt_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(_showCreateForm ? 'Misiones' : 'Nueva'),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String value) {
    final selected = controller.filterEstado.value == value;
    return InkWell(
      onTap: () => controller.filterEstado.value = value,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.neonCyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppConstants.neonCyan.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          DtexMision.estadoLabel(value).toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? AppConstants.neonCyan : Colors.white70,
            fontFamily: 'Rajdhani',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMissionList() {
    return _panel(
      title: 'MISIONES DTEX',
      color: AppConstants.neonCyan,
      child: Obx(() {
        if (controller.isLoading.value && controller.misiones.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppConstants.neonCyan),
          );
        }

        final misiones = controller.misionesFiltradas;
        if (misiones.isEmpty) {
          return _emptyState(
            icon: Icons.assignment_late_rounded,
            text: 'Sin misiones para el filtro actual.',
          );
        }

        return ListView.separated(
          itemCount: misiones.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          itemBuilder: (context, index) {
            final m = misiones[index];
            final selected =
                controller.misionSeleccionada.value?.idMision == m.idMision;
            return _missionTile(m, selected);
          },
        );
      }),
    );
  }

  Widget _missionTile(DtexMision mission, bool selected) {
    final color = _statusColor(mission.estado);
    return InkWell(
      onTap: () {
        setState(() => _showCreateForm = false);
        controller.seleccionarMision(mission);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_shipping_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.reoNombre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${mission.tipoDiligenciaDisplay} | ${mission.destinoNombre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontFamily: 'Rajdhani',
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _miniTag(mission.estadoDisplay, color),
                      _miniTag(mission.custodioCodigo, Colors.white54),
                      if (mission.tiempoDestinoVencido)
                        _miniTag('TIEMPO VENCIDO', AppConstants.warningRed),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionDetail() {
    return _panel(
      title: 'DETALLE Y TRACKING',
      color: AppConstants.successGreen,
      child: Obx(() {
        final mission = controller.misionSeleccionada.value;
        if (mission == null) {
          return _emptyState(
            icon: Icons.route_outlined,
            text: 'Selecciona una mision para ver tracking y control.',
          );
        }

        final last = controller.ultimaPosicion;
        final elapsed = controller.tiempoMisionActiva;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.reoNombre.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'CI ${mission.reoCi} | EXP ${mission.reoExpediente ?? 'N/A'}',
                        style: _mutedTextStyle(),
                      ),
                    ],
                  ),
                ),
                _statusPill(
                    mission.estadoDisplay, _statusColor(mission.estado)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoBox('TIPO', mission.tipoDiligenciaDisplay),
                _infoBox('DESTINO', mission.destinoNombre),
                _infoBox('CUSTODIO', mission.custodioNombre),
                _infoBox('CODIGO', mission.custodioCodigo),
                _infoBox('GRADO', mission.custodioGrado),
                _infoBox('SALIDA', _formatTime(mission.horaSalidaAutorizada)),
                _infoBox('OTP',
                    mission.codigoOtp.isEmpty ? 'N/A' : mission.codigoOtp),
                _infoBox(
                  'TIEMPO',
                  elapsed == null ? 'N/A' : _formatDuration(elapsed),
                ),
                if (mission.conductaFinal != null)
                  _infoBox(
                    'CONDUCTA',
                    DtexMision.conductaDisplay(mission.conductaFinal!),
                  ),
              ],
            ),
            if (mission.codigoOtp.isNotEmpty && mission.estaActiva) ...[
              const SizedBox(height: 12),
              _buildCustodioAccessCard(mission.codigoOtp),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ULTIMA POSICION', style: _sectionTitleStyle()),
                  const SizedBox(height: 6),
                  Text(
                    last == null
                        ? 'Sin puntos GPS recibidos para esta mision.'
                        : '${last.latitud.toStringAsFixed(6)}, ${last.longitud.toStringAsFixed(6)} | BAT ${last.bateriaPct ?? '--'}% | ${_formatTime(last.ts)}',
                    style: _mutedTextStyle(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puntos cargados: ${controller.trackingActivo.length}',
                    style: _mutedTextStyle(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _conductaFinal,
              dropdownColor: const Color(0xFF07111D),
              decoration: _inputDecoration(
                label: 'Conducta final',
                color: AppConstants.successGreen,
              ),
              items: DtexMision.conductasFinales
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        DtexMision.conductaDisplay(value),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: mission.esCerrada
                  ? null
                  : (value) => setState(
                        () => _conductaFinal =
                            value ?? DtexMision.conductaSinIncidencias,
                      ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.alertOrange,
                      side: BorderSide(
                        color: AppConstants.alertOrange.withValues(alpha: 0.7),
                      ),
                    ),
                    onPressed: mission.isPendiente
                        ? () => controller.cancelarMision(mission.idMision)
                        : null,
                    icon: const Icon(Icons.cancel_rounded, size: 17),
                    label: const Text('Cancelar pendiente'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppConstants.successGreen,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: mission.esCerrada
                        ? null
                        : () => _cerrarMision(mission.idMision),
                    icon: const Icon(Icons.check_circle_rounded, size: 17),
                    label: const Text('Cerrar mision'),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEventPanels() {
    return Row(
      children: [
        Expanded(child: _buildAlertsPanel()),
        const SizedBox(width: 10),
        Expanded(child: _buildExtensionsPanel()),
      ],
    );
  }

  Widget _buildAlertsPanel() {
    return _panel(
      title: 'ALERTAS DTEX',
      color: AppConstants.warningRed,
      child: Obx(() {
        final rows = controller.alertasPendientes;
        if (rows.isEmpty) {
          return _emptyState(
            icon: Icons.notifications_none_rounded,
            text: 'Sin alertas pendientes.',
            small: true,
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, index) => _alertTile(rows[index]),
        );
      }),
    );
  }

  Widget _alertTile(DtexAlerta alerta) {
    final color = alerta.esEmergencia
        ? AppConstants.warningRed
        : AppConstants.alertOrange;
    return ListTile(
      dense: true,
      minLeadingWidth: 20,
      leading: Icon(Icons.warning_rounded, color: color, size: 18),
      title: Text(
        alerta.tipoDisplay,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        alerta.descripcion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _mutedTextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        tooltip: 'Resolver alerta',
        icon: const Icon(Icons.done_rounded, size: 18),
        color: AppConstants.successGreen,
        onPressed: () => _resolverAlerta(alerta),
      ),
    );
  }

  Widget _buildExtensionsPanel() {
    return _panel(
      title: 'EXTENSIONES',
      color: AppConstants.alertOrange,
      child: Obx(() {
        final rows = controller.extensiones;
        if (rows.isEmpty) {
          return _emptyState(
            icon: Icons.more_time_rounded,
            text: 'Sin solicitudes de extension.',
            small: true,
          );
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, index) => _extensionTile(rows[index]),
        );
      }),
    );
  }

  Widget _extensionTile(DtexExtension ext) {
    return ListTile(
      dense: true,
      minLeadingWidth: 20,
      leading: const Icon(
        Icons.more_time_rounded,
        color: AppConstants.alertOrange,
        size: 18,
      ),
      title: Text(
        '+${ext.minutosSolicitados} min',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      subtitle: Text(
        ext.motivo,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _mutedTextStyle(fontSize: 11),
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Rechazar',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppConstants.warningRed,
            onPressed: () => controller.responderExtension(
              idExtension: ext.idExtension,
              aprobada: false,
            ),
          ),
          IconButton(
            tooltip: 'Aprobar',
            icon: const Icon(Icons.done_rounded, size: 18),
            color: AppConstants.successGreen,
            onPressed: () => controller.responderExtension(
              idExtension: ext.idExtension,
              aprobada: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return _panel(
      title: 'NUEVA MISION DTEX',
      color: AppConstants.neonCyan,
      child: Obx(() {
        final destinos = controller.destinos;
        if (_destinoId == null && destinos.isNotEmpty) {
          _destinoId = destinos.first.idDestino;
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeButton('JUDICIAL'),
                _typeButton('HOSPITALARIA'),
                _typeButton('PERSONAL'),
                _typeButton('PERMISO_ESPECIAL'),
              ],
            ),
            const SizedBox(height: 12),
            _textField(_reoNombreController, 'Nombre del interno'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _textField(_reoCiController, 'CI interno')),
                const SizedBox(width: 8),
                Expanded(
                    child: _textField(_expedienteController, 'Expediente')),
              ],
            ),
            const SizedBox(height: 8),
            _textField(_custodioNombreController, 'Custodio responsable'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _textField(_custodioCodigoController, 'Codigo')),
                const SizedBox(width: 8),
                Expanded(child: _textField(_custodioGradoController, 'Grado')),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _destinoId,
              dropdownColor: const Color(0xFF07111D),
              decoration: _inputDecoration(
                label: 'Destino autorizado',
                color: AppConstants.neonCyan,
              ),
              items: destinos
                  .map(
                    (d) => DropdownMenuItem<String>(
                      value: d.idDestino,
                      child: Text(
                        '${d.nombre} (${d.tipoDisplay})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _destinoId = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _salidaEnMinController,
                    'Salida en minutos',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _textField(
                    _tiempoMaxController,
                    'Max destino min',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _textField(_referenciaController, 'Referencia legal'),
            const SizedBox(height: 8),
            _textField(_notasController, 'Notas operativas', maxLines: 2),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.neonCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: controller.isLoading.value ? null : _crearMision,
              icon: const Icon(Icons.key_rounded, size: 18),
              label: const Text('Crear mision y generar OTP'),
            ),
            if (controller.otpGenerado.value != null) ...[
              const SizedBox(height: 12),
              _buildCustodioAccessCard(controller.otpGenerado.value!),
            ],
          ],
        );
      }),
    );
  }

  Widget _typeButton(String value) {
    final selected = _tipoDiligencia == value;
    return InkWell(
      onTap: () => setState(() => _tipoDiligencia = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.neonCyan.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppConstants.neonCyan.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: selected ? AppConstants.neonCyan : Colors.white70,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildCustodioAccessCard(String otp) {
    final link = _custodioLink(otp);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.successGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppConstants.successGreen.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 104,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OTP ACTIVO: $otp',
                  style: const TextStyle(
                    color: AppConstants.successGreen,
                    fontFamily: 'Orbitron',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  link,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedTextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.successGreen,
                      side: BorderSide(
                        color:
                            AppConstants.successGreen.withValues(alpha: 0.65),
                      ),
                    ),
                    onPressed: () => _copyCustodioLink(link),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar enlace'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani'),
      decoration: _inputDecoration(label: label, color: AppConstants.neonCyan),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required Color color,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.22),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color.withValues(alpha: 0.8)),
      ),
    );
  }

  Future<void> _crearMision() async {
    final destino = _selectedDestino();
    final salidaMin = int.tryParse(_salidaEnMinController.text.trim()) ?? 15;
    final tiempoMax = int.tryParse(_tiempoMaxController.text.trim()) ?? 60;

    if (destino == null ||
        _reoNombreController.text.trim().isEmpty ||
        _reoCiController.text.trim().isEmpty ||
        _custodioNombreController.text.trim().isEmpty ||
        _custodioCodigoController.text.trim().isEmpty ||
        _custodioGradoController.text.trim().isEmpty) {
      Get.snackbar(
        'DTEX',
        'Completa interno, custodio y destino antes de crear la mision.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppConstants.alertOrange.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    final otp = await controller.crearMision(
      tipoDiligencia: _tipoDiligencia,
      reoNombre: _reoNombreController.text.trim(),
      reoCi: _reoCiController.text.trim(),
      reoExpediente: _nullableText(_expedienteController),
      custodioNombre: _custodioNombreController.text.trim(),
      custodioCodigo: _custodioCodigoController.text.trim(),
      custodioGrado: _custodioGradoController.text.trim(),
      destino: destino,
      horaSalida: DateTime.now().add(Duration(minutes: salidaMin)),
      tiempoMaxMin: tiempoMax,
      referenciaLegal: _nullableText(_referenciaController),
      notas: _nullableText(_notasController),
    );

    if (otp == null) return;
    _clearCreateForm(keepOtp: true);
    setState(() => _showCreateForm = false);
  }

  Future<void> _cerrarMision(String idMision) async {
    if (!DtexMision.conductaFinalValida(_conductaFinal)) {
      Get.snackbar(
        'DTEX',
        'Selecciona una conducta final antes de cerrar la mision.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    await controller.cerrarMisionManual(
      idMision: idMision,
      conductaFinal: _conductaFinal,
    );
    setState(() => _conductaFinal = DtexMision.conductaSinIncidencias);
  }

  Future<void> _resolverAlerta(DtexAlerta alerta) async {
    _resolucionController.clear();
    await Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppConstants.darkBg,
        title: const Text(
          'RESOLVER ALERTA DTEX',
          style: TextStyle(
            color: AppConstants.warningRed,
            fontFamily: 'Orbitron',
            fontSize: 13,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alerta.tipoDisplay, style: _sectionTitleStyle()),
              const SizedBox(height: 6),
              Text(alerta.descripcion, style: _mutedTextStyle()),
              const SizedBox(height: 12),
              TextField(
                controller: _resolucionController,
                maxLines: 3,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rajdhani',
                ),
                decoration: _inputDecoration(
                  label: 'Nota de resolucion',
                  color: AppConstants.warningRed,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('CANCELAR', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.successGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Get.back();
              await controller.resolverAlerta(
                idAlerta: alerta.idAlerta,
                nota: _nullableText(_resolucionController),
              );
            },
            child: const Text('RESOLVER'),
          ),
        ],
      ),
    );
  }

  DtexDestino? _selectedDestino() {
    final id = _destinoId;
    if (id == null) return null;
    return controller.destinos.firstWhereOrNull((d) => d.idDestino == id);
  }

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  String _custodioLink(String otp) {
    return Uri.base
        .replace(
          path: '/dtex/custodio',
          queryParameters: {'otp': otp},
          fragment: '',
        )
        .toString();
  }

  Future<void> _copyCustodioLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    Get.snackbar(
      'DTEX',
      'Enlace temporal copiado.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: AppConstants.successGreen.withValues(alpha: 0.16),
      colorText: AppConstants.successGreen,
    );
  }

  void _clearCreateForm({bool keepOtp = false}) {
    _reoNombreController.clear();
    _reoCiController.clear();
    _expedienteController.clear();
    _custodioNombreController.clear();
    _custodioCodigoController.clear();
    _custodioGradoController.clear();
    _salidaEnMinController.text = '15';
    _tiempoMaxController.text = '60';
    _referenciaController.clear();
    _notasController.clear();
    if (!keepOtp) controller.otpGenerado.value = null;
  }

  Widget _panel({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String text,
    bool small = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.28),
              size: small ? 26 : 38,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontFamily: 'Rajdhani',
                fontSize: small ? 11 : 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiChip(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontFamily: 'Rajdhani',
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'Rajdhani',
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Rajdhani',
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 210),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppConstants.neonCyan.withValues(alpha: 0.75),
              fontFamily: 'Orbitron',
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _sectionTitleStyle() {
    return const TextStyle(
      color: Colors.white,
      fontFamily: 'Orbitron',
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle _mutedTextStyle({double fontSize = 12}) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.66),
      fontFamily: 'Rajdhani',
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  Color _statusColor(String estado) {
    switch (estado.trim().toUpperCase()) {
      case DtexMision.estadoAbierta:
        return AppConstants.alertOrange;
      case DtexMision.estadoRegistroRealizado:
        return Colors.amberAccent;
      case DtexMision.estadoEnRuta:
      case DtexMision.estadoRetorno:
        return AppConstants.neonCyan;
      case DtexMision.estadoEnDestino:
        return AppConstants.successGreen;
      case DtexMision.estadoEmergencia:
        return AppConstants.warningRed;
      case DtexMision.estadoCompletada:
        return Colors.white54;
      case DtexMision.estadoCancelada:
        return Colors.blueGrey;
      default:
        return Colors.white70;
    }
  }

  String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }
}
