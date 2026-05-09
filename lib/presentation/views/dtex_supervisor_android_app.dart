import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/repositories/supabase_repository.dart';
import '../controllers/auth_controller.dart';
import '../controllers/dtex_controller.dart';
import 'dtex_supervisor/widgets/dtex_shared_widgets.dart';

class DtexSupervisorAndroidApp extends StatelessWidget {
  const DtexSupervisorAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'DTEX Supervisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConstants.darkBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.neonCyan,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Rajdhani',
      ),
      home: const DtexSupervisorRoot(),
    );
  }
}

class DtexSupervisorRoot extends StatelessWidget {
  const DtexSupervisorRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.isInitialized.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final admin = auth.currentAdmin.value;
      if (admin == null) return DtexSupervisorLogin(auth: auth);
      if (!admin.tieneAccesoDtex) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Usuario sin acceso DTEX.',
                style: dtexTitleStyle(color: AppConstants.warningRed),
              ),
            ),
          ),
        );
      }
      if (!Get.isRegistered<DtexController>()) {
        Get.put(DtexController(), permanent: true);
      }
      return DtexSupervisorHome(auth: auth, controller: Get.find());
    });
  }
}

class DtexSupervisorLogin extends StatefulWidget {
  const DtexSupervisorLogin({super.key, required this.auth});

  final AuthController auth;

  @override
  State<DtexSupervisorLogin> createState() => _DtexSupervisorLoginState();
}

class _DtexSupervisorLoginState extends State<DtexSupervisorLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 42, 18, 18),
          children: [
            const Icon(Icons.admin_panel_settings_rounded,
                color: AppConstants.neonCyan, size: 58),
            const SizedBox(height: 16),
            Text('DTEX SUPERVISOR',
                textAlign: TextAlign.center, style: dtexTitleStyle()),
            const SizedBox(height: 6),
            Text('Command center operativo Android',
                textAlign: TextAlign.center, style: dtexMutedStyle()),
            const SizedBox(height: 28),
            dtexPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Correo supervisor'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: dtexInputDecoration('Contraseña'),
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AppConstants.warningRed)),
                  ],
                  const SizedBox(height: 18),
                  Obx(
                    () => FilledButton.icon(
                      onPressed: widget.auth.isLoading.value ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppConstants.neonCyan,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(widget.auth.isLoading.value
                          ? 'Validando'
                          : 'Ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    final ok = await widget.auth.login(
      email: _email.text.trim(),
      password: _password.text.trim(),
    );
    if (!mounted) return;
    final admin = widget.auth.currentAdmin.value;
    setState(() {
      _error = ok && admin?.tieneAccesoDtex == true
          ? null
          : 'Credenciales inválidas o sin acceso DTEX.';
    });
  }
}

class DtexSupervisorHome extends StatefulWidget {
  const DtexSupervisorHome({
    super.key,
    required this.auth,
    required this.controller,
  });

  final AuthController auth;
  final DtexController controller;

  @override
  State<DtexSupervisorHome> createState() => _DtexSupervisorHomeState();
}

class _DtexSupervisorHomeState extends State<DtexSupervisorHome> {
  final _repo = SupabaseRepository();
  int _index = 0;

  DtexController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(controller: c),
      _AssignTaskTab(controller: c),
      _MapTab(controller: c),
      _AlertsTab(controller: c),
      _RadioTab(controller: c, repository: _repo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('DTEX Supervisor'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: c.loadInitialData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Salir',
            onPressed: widget.auth.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.add_task_rounded), label: 'Asignar'),
          NavigationDestination(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          NavigationDestination(
              icon: Icon(Icons.warning_rounded), label: 'Alertas'),
          NavigationDestination(
              icon: Icon(Icons.radio_rounded), label: 'Radio'),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.controller});

  final DtexController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(
                    'Activas',
                    controller.misionesActivas.length.toString(),
                    AppConstants.neonCyan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                    'Alertas',
                    controller.alertasPendientes.length.toString(),
                    AppConstants.warningRed),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metric(
                    'Destinos',
                    controller.destinos.length.toString(),
                    AppConstants.successGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                    'Extensiones',
                    controller.extensiones.length.toString(),
                    AppConstants.alertOrange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Misiones activas', style: dtexSectionStyle()),
          const SizedBox(height: 8),
          for (final mission in controller.misionesActivas)
            _missionTile(controller, mission),
        ],
      ),
    );
  }
}

class _AssignTaskTab extends StatefulWidget {
  const _AssignTaskTab({required this.controller});

  final DtexController controller;

  @override
  State<_AssignTaskTab> createState() => _AssignTaskTabState();
}

class _AssignTaskTabState extends State<_AssignTaskTab> {
  final _reo = TextEditingController();
  final _ci = TextEditingController();
  final _exp = TextEditingController();
  final _custodio = TextEditingController();
  final _codigo = TextEditingController();
  final _grado = TextEditingController();
  final _salidaMin = TextEditingController(text: '0');
  final _maxMin = TextEditingController(text: '120');
  final _ref = TextEditingController();
  String _tipo = 'JUDICIAL';
  String? _destinoId;
  String? _otp;

  @override
  void dispose() {
    _reo.dispose();
    _ci.dispose();
    _exp.dispose();
    _custodio.dispose();
    _codigo.dispose();
    _grado.dispose();
    _salidaMin.dispose();
    _maxMin.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final destinos = widget.controller.destinos;
      if (_destinoId == null && destinos.isNotEmpty) {
        _destinoId = destinos.first.idDestino;
      }
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Asignar diligencia', style: dtexSectionStyle()),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _tipo,
            decoration: dtexInputDecoration('Tipo'),
            items: const ['JUDICIAL', 'HOSPITALARIA', 'PERSONAL']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (value) => setState(() => _tipo = value ?? _tipo),
          ),
          const SizedBox(height: 8),
          _field(_reo, 'Interno'),
          const SizedBox(height: 8),
          _field(_ci, 'CI interno'),
          const SizedBox(height: 8),
          _field(_exp, 'Expediente'),
          const SizedBox(height: 8),
          _field(_custodio, 'Custodio'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_codigo, 'Código custodio')),
              const SizedBox(width: 8),
              Expanded(child: _field(_grado, 'Grado')),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _destinoId,
            decoration: dtexInputDecoration('Destino'),
            items: destinos
                .map((d) => DropdownMenuItem(
                      value: d.idDestino,
                      child: Text(d.nombre, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _destinoId = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _field(_salidaMin, 'Salida min')),
              const SizedBox(width: 8),
              Expanded(child: _field(_maxMin, 'Max estadía')),
            ],
          ),
          const SizedBox(height: 8),
          _field(_ref, 'Referencia legal'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.controller.isLoading.value ? null : _create,
            icon: const Icon(Icons.key_rounded),
            label: const Text('Crear misión y OTP'),
          ),
          if (_otp != null) ...[
            const SizedBox(height: 12),
            dtexPanel(
              child: Column(
                children: [
                  Text('OTP generado: $_otp',
                      style: dtexTitleStyle(color: AppConstants.successGreen)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: _otp!)),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar código'),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Future<void> _create() async {
    final destino = widget.controller.destinos
        .firstWhereOrNull((d) => d.idDestino == _destinoId);
    if (destino == null ||
        _reo.text.trim().isEmpty ||
        _ci.text.trim().isEmpty ||
        _custodio.text.trim().isEmpty ||
        _codigo.text.trim().isEmpty ||
        _grado.text.trim().isEmpty) {
      Get.snackbar('DTEX', 'Completa los datos obligatorios.');
      return;
    }
    final otp = await widget.controller.crearMision(
      tipoDiligencia: _tipo,
      reoNombre: _reo.text.trim(),
      reoCi: _ci.text.trim(),
      reoExpediente: _nullable(_exp),
      custodioNombre: _custodio.text.trim(),
      custodioCodigo: _codigo.text.trim(),
      custodioGrado: _grado.text.trim(),
      destino: destino,
      horaSalida: DateTime.now()
          .add(Duration(minutes: int.tryParse(_salidaMin.text) ?? 0)),
      tiempoMaxMin: int.tryParse(_maxMin.text) ?? 120,
      referenciaLegal: _nullable(_ref),
    );
    setState(() => _otp = otp);
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab({required this.controller});

  final DtexController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.misionSeleccionada.value;
      final points = controller.trackingActivo;
      final last = points.isNotEmpty ? points.last : null;
      
      // Lógica de destino para el Jefe de Seguridad
      LatLng? destinationPos;
      if (selected != null) {
        final dest = controller.destinos.firstWhereOrNull(
          (d) => d.nombre == selected.destinoNombre
        );
        if (dest != null) {
          destinationPos = LatLng(dest.latitud, dest.longitud);
        }
      }

      final center = last == null
          ? const LatLng(
              AppConstants.defaultLatitude, AppConstants.defaultLongitude)
          : LatLng(last.latitud, last.longitud);
      return Column(
        children: [
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: [
                for (final mission in controller.misionesActivas)
                  SizedBox(
                    width: 260,
                    child: _missionTile(controller, mission),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sccp_command_center.dtex_supervisor',
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points
                            .map((p) => LatLng(p.latitud, p.longitud))
                            .toList(),
                        color: AppConstants.neonCyan,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (last != null)
                      Marker(
                        point: LatLng(last.latitud, last.longitud),
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.navigation_rounded,
                            color: AppConstants.neonCyan, size: 34),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(selected.destinoNombre, style: dtexMutedStyle()),
            ),
        ],
      );
    });
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.controller});

  final DtexController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.alertasPendientes;
      if (rows.isEmpty) {
        return Center(
            child: Text('Sin alertas pendientes.', style: dtexMutedStyle()));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, index) => _alertTile(controller, rows[index]),
      );
    });
  }
}

class _RadioTab extends StatefulWidget {
  const _RadioTab({required this.controller, required this.repository});

  final DtexController controller;
  final SupabaseRepository repository;

  @override
  State<_RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<_RadioTab> {
  final _message = TextEditingController();
  String? _targetId;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final missions = widget.controller.misionesActivas;
      _targetId ??= missions.isNotEmpty ? missions.first.custodioCodigo : null;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: _targetId,
              decoration: dtexInputDecoration('Custodio'),
              items: missions
                  .map((m) => DropdownMenuItem(
                        value: m.custodioCodigo,
                        child: Text(m.custodioNombre,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _targetId = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RadioMessage>>(
              stream:
                  widget.repository.watchRadioMessages(idOficial: _targetId),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const <RadioMessage>[];
                if (rows.isEmpty) {
                  return Center(
                      child: Text('Sin mensajes.', style: dtexMutedStyle()));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final msg = rows[index];
                    final fromSupervisor =
                        msg.deUsuario.trim().toUpperCase() == 'SUPERVISOR';
                    return Align(
                      alignment: fromSupervisor
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: dtexPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${msg.deUsuario} • ${msg.tipo}',
                                style: dtexMutedStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(msg.mensaje),
                            if (msg.tipo == 'PARTE_NOVEDAD' &&
                                msg.mensaje.contains('http')) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  msg.mensaje.split(' ').firstWhere(
                                      (s) => s.startsWith('http'),
                                      orElse: () => ''),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_rounded, size: 40),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 3,
                    decoration: dtexInputDecoration('Mensaje'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Future<void> _send() async {
    final target = _targetId;
    final text = _message.text.trim();
    if (target == null || target.isEmpty || text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.repository.sendRadioMessage(
      idOficial: target,
      fromUser: 'SUPERVISOR',
      toUser: 'DTEX:$target',
      message: text,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _message.clear();
    });
  }
}

Widget _missionTile(DtexController controller, DtexMision mission) {
  final puedeCerrar = [
    DtexMision.estadoEnDestino,
    DtexMision.estadoRetorno,
    DtexMision.estadoEmergencia
  ].contains(mission.estadoNormalizado);

  return Card(
    child: ListTile(
      onTap: () => controller.seleccionarMision(mission),
      title: Text(mission.custodioNombre, overflow: TextOverflow.ellipsis),
      subtitle: Text('${mission.estadoDisplay} • ${mission.destinoNombre}',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (puedeCerrar)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded, color: AppConstants.successGreen),
              onPressed: () => _showCierreDialog(Get.context!, controller, mission),
            ),
          Icon(Icons.chevron_right_rounded,
              color: _stateColor(mission.estadoNormalizado)),
        ],
      ),
    ),
  );
}

void _showCierreDialog(BuildContext context, DtexController controller, DtexMision mission) {
  String conducta = 'SIN_INCIDENCIAS';
  final obs = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Finalizar Diligencia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: conducta,
            items: const [
              DropdownMenuItem(value: 'SIN_INCIDENCIAS', child: Text('Sin incidencias')),
              DropdownMenuItem(value: 'CON_OBSERVACIONES', child: Text('Con observaciones')),
              DropdownMenuItem(value: 'CON_INCIDENCIAS_GRAVES', child: Text('Incidencias graves')),
            ],
            onChanged: (v) => conducta = v ?? conducta,
            decoration: dtexInputDecoration('Conducta final'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: obs,
            decoration: dtexInputDecoration('Observaciones'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('CANCELAR')),
        FilledButton(
          onPressed: () async {
            await controller.cerrarMisionConConducta(
              idMision: mission.idMision,
              conducta: conducta,
              observaciones: obs.text.trim(),
            );
            Get.back();
          },
          child: const Text('CERRAR MISIÓN'),
        ),
      ],
    ),
  );
}

Widget _alertTile(DtexController controller, DtexAlerta alerta) {
  return Card(
    color: alerta.esEmergencia 
        ? AppConstants.warningRed.withValues(alpha: 0.15) 
        : null,
    child: ListTile(
      leading: Icon(Icons.warning_rounded,
          color: alerta.esEmergencia
              ? AppConstants.warningRed
              : AppConstants.alertOrange),
      title: Text(
        alerta.tipoDisplay,
        style: TextStyle(fontWeight: alerta.esEmergencia ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(alerta.descripcion,
          maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.done_rounded),
        onPressed: () => controller.resolverAlerta(idAlerta: alerta.idAlerta),
      ),
    ),
  );
}

Widget _metric(String label, String value, Color color) {
  return dtexPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: dtexMutedStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: dtexTitleStyle(color: color)),
      ],
    ),
  );
}

Widget _field(TextEditingController controller, String label) {
  return TextField(controller: controller, decoration: dtexInputDecoration(label));
}

Color _stateColor(String state) {
  switch (state) {
    case DtexMision.estadoEmergencia:
      return AppConstants.warningRed;
    case DtexMision.estadoEnDestino:
      return AppConstants.successGreen;
    case DtexMision.estadoEnRuta:
    case DtexMision.estadoRetorno:
      return AppConstants.neonCyan;
    default:
      return AppConstants.alertOrange;
  }
}

String? _nullable(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
}
