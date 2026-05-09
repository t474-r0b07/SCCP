import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/utils/grado_assets.dart';
import '../../data/models/oficial_model.dart';
import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import 'pin_pad.dart';

class GestionOficialesDialog extends StatefulWidget {
  const GestionOficialesDialog({super.key});

  @override
  State<GestionOficialesDialog> createState() => _GestionOficialesDialogState();
}

class _GestionOficialesDialogState extends State<GestionOficialesDialog> {
  final DashboardController _dashboard = Get.find<DashboardController>();
  final AuthController _auth = Get.find<AuthController>();

  final _idController = TextEditingController();
  final _nombreController = TextEditingController();
  final _imeiController = TextEditingController();
  final _reoNuevoCodigoController = TextEditingController();
  final _reoNombreController = TextEditingController();
  final _reoDocumentoController = TextEditingController();
  final _reoCoordsController = TextEditingController();
  final _reoDireccionController = TextEditingController();
  final _reoTelefonoController = TextEditingController();
  final _reoObsController = TextEditingController();

  String _modoOperacion = 'REGISTRAR';
  String _grupo = 'ALFA';
  String _grado = GradoAssets.defaultGrade;
  bool _activo = true;
  bool _registrarReoNuevo = false;

  final Set<String> _selectedIds = <String>{};
  String? _editingId;
  String _batchGrupo = 'ALFA';
  String? _reemplazoSalienteId;
  String? _reemplazoEntranteId;

  @override
  void dispose() {
    _idController.dispose();
    _nombreController.dispose();
    _imeiController.dispose();
    _reoNuevoCodigoController.dispose();
    _reoNombreController.dispose();
    _reoDocumentoController.dispose();
    _reoCoordsController.dispose();
    _reoDireccionController.dispose();
    _reoTelefonoController.dispose();
    _reoObsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final mobileDialog = media.width < 980 || media.shortestSide < 760;
    final dialogWidth =
        (mobileDialog ? (media.width - 12) : 1050).clamp(260.0, 1050.0);
    final dialogHeight =
        (mobileDialog ? media.height * 0.94 : 690).clamp(520.0, 760.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mobileDialog ? 6 : 24,
        vertical: mobileDialog ? 10 : 24,
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: dialogWidth.toDouble(),
          height: dialogHeight.toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: AppConstants.darkBg.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppConstants.neonCyan.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                _buildHeader(compact: mobileDialog),
                Expanded(
                  child: mobileDialog
                      ? DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              TabBar(
                                labelColor: AppConstants.neonCyan,
                                unselectedLabelColor:
                                    Colors.white.withValues(alpha: 0.72),
                                labelStyle: const TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                indicatorColor: AppConstants.neonCyan,
                                tabs: const [
                                  Tab(text: 'OFICIALES'),
                                  Tab(text: 'FORMULARIO'),
                                  Tab(text: 'MASIVO'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildOficialesList(),
                                    _buildFormPanel(),
                                    _buildBatchPanel(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(flex: 4, child: _buildOficialesList()),
                            const VerticalDivider(
                                color: Colors.white12, width: 1),
                            Expanded(flex: 5, child: _buildFormPanel()),
                            const VerticalDivider(
                                color: Colors.white12, width: 1),
                            Expanded(flex: 3, child: _buildBatchPanel()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppConstants.neonCyan.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: AppConstants.neonCyan,
            size: compact ? 18 : 22,
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Text(
              'GESTION DE OFICIALES',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                letterSpacing: compact ? 0.6 : 1.1,
                fontSize: compact ? 11.5 : 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Get.back(),
            visualDensity:
                compact ? VisualDensity.compact : VisualDensity.standard,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildOficialesList() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LISTA OFICIALES (${_selectedIds.length} seleccionados)',
            style: TextStyle(
              color: AppConstants.neonCyan.withValues(alpha: 0.9),
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              final list = _dashboard.oficiales;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final o = list[index];
                  final selected = _selectedIds.contains(o.idOficial);
                  final editing = _editingId == o.idOficial;
                  return InkWell(
                    onTap: () => _loadToForm(o),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: editing
                            ? AppConstants.neonCyan.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: editing
                              ? AppConstants.neonCyan
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            activeColor: AppConstants.neonCyan,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(o.idOficial);
                                } else {
                                  _selectedIds.remove(o.idOficial);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.nombreOficial,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${o.idOficial} · ${o.grupo ?? 'N/D'}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontFamily: 'Rajdhani',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: o.activo
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    final requiresSelection = _modoOperacion != 'REGISTRAR';
    final hasSelection = _editingId != null;
    final isNarrow = MediaQuery.of(context).size.width < 760;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FLUJO GUIADO',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel('PASO 1: OPERACION'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _modeBtn('REGISTRAR'),
                _modeBtn('MODIFICAR'),
                _modeBtn('ELIMINAR'),
              ],
            ),
            const SizedBox(height: 10),
            _sectionLabel('PASO 2: GRUPO'),
            const SizedBox(height: 6),
            _drop(
              label: 'GRUPO',
              value: _grupo,
              items: const ['ALFA', 'BRAVO'],
              onChanged: (v) => setState(() => _grupo = v),
            ),
            const SizedBox(height: 10),
            _sectionLabel(
              requiresSelection
                  ? 'PASO 3: SELECCIONA OFICIAL EN LISTA IZQUIERDA'
                  : 'PASO 3: COMPLETA DATOS',
            ),
            const SizedBox(height: 8),
            if (requiresSelection && !hasSelection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Selecciona un oficial de la lista para continuar.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_modoOperacion != 'ELIMINAR') ...[
              _inputField(
                _idController,
                'ID OFICIAL',
                readOnly: _modoOperacion == 'MODIFICAR',
              ),
              _inputField(_nombreController, 'NOMBRE OFICIAL'),
              _inputField(_imeiController, 'IMEI'),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _registrarReoNuevo,
                activeThumbColor: AppConstants.neonGreen,
                activeTrackColor:
                    AppConstants.neonGreen.withValues(alpha: 0.45),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text(
                  'REGISTRAR REO NUEVO EN TABLA REOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _registrarReoNuevo = value),
              ),
              if (_registrarReoNuevo) ...[
                _inputField(_reoNuevoCodigoController, 'CODIGO REO NUEVO'),
                _inputField(_reoNombreController, 'NOMBRE COMPLETO DEL REO'),
                _inputField(_reoDocumentoController, 'DOCUMENTO IDENTIDAD'),
                _inputField(_reoCoordsController, 'COORDENADAS CASA (LAT,LNG)'),
                _inputField(_reoDireccionController, 'DIRECCION CASA'),
                _inputField(_reoTelefonoController, 'TELEFONO'),
                _inputField(_reoObsController, 'OBSERVACIONES'),
              ],
              if (isNarrow) ...[
                _drop(
                  label: 'GRADO',
                  value: _grado,
                  items: GradoAssets.catalog,
                  onChanged: (v) => setState(() => _grado = v),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: _activo,
                  activeThumbColor: AppConstants.neonCyan,
                  activeTrackColor:
                      AppConstants.neonCyan.withValues(alpha: 0.45),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: const Text(
                    'ACTIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  onChanged: (value) => setState(() => _activo = value),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _drop(
                        label: 'GRADO',
                        value: _grado,
                        items: GradoAssets.catalog,
                        onChanged: (v) => setState(() => _grado = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SwitchListTile(
                        value: _activo,
                        activeThumbColor: AppConstants.neonCyan,
                        activeTrackColor:
                            AppConstants.neonCyan.withValues(alpha: 0.45),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        title: const Text(
                          'ACTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        onChanged: (value) => setState(() => _activo = value),
                      ),
                    ),
                  ],
                ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppConstants.warningRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  hasSelection
                      ? 'Oficial seleccionado: ${_nombreController.text} (${_idController.text})'
                      : 'Debes seleccionar un oficial para eliminar.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _sectionLabel('PASO 4: CONFIRMAR Y GUARDAR'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionBtn('NUEVO', Colors.white70, _clearForm),
                if (_modoOperacion == 'REGISTRAR')
                  _actionBtn(
                      'GUARDAR REGISTRO', AppConstants.neonGreen, _register),
                if (_modoOperacion == 'MODIFICAR')
                  _actionBtn('GUARDAR CAMBIOS', AppConstants.neonCyan, _update),
                if (_modoOperacion == 'ELIMINAR')
                  _actionBtn(
                      'ELIMINAR OFICIAL', AppConstants.warningRed, _deactivate),
                _actionBtn('REACTIVAR', Colors.amberAccent, _activate),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchPanel() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ACCIONES MASIVAS',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _drop(
              label: 'GRUPO DESTINO',
              value: _batchGrupo,
              items: const ['ALFA', 'BRAVO'],
              onChanged: (v) => setState(() => _batchGrupo = v),
            ),
            const SizedBox(height: 12),
            _actionBtn('APLICAR GRUPO', AppConstants.neonCyan, _batchGroup),
            const SizedBox(height: 8),
            _actionBtn('DESACTIVAR SELECCION', AppConstants.warningRed,
                _batchDeactivate),
            const SizedBox(height: 8),
            _actionBtn(
                'ACTIVAR SELECCION', AppConstants.neonGreen, _batchActivate),
            const SizedBox(height: 16),
            const Text(
              'REEMPLAZO RAPIDO',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            _oficialDropOptional(
              label: 'OFICIAL SALIENTE',
              value: _reemplazoSalienteId,
              onChanged: (v) => setState(() => _reemplazoSalienteId = v),
            ),
            const SizedBox(height: 8),
            _oficialDropOptional(
              label: 'OFICIAL ENTRANTE',
              value: _reemplazoEntranteId,
              onChanged: (v) => setState(() => _reemplazoEntranteId = v),
            ),
            const SizedBox(height: 8),
            _actionBtn(
                'APLICAR REEMPLAZO', Colors.amberAccent, _applyReplacement),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppConstants.neonCyan.withValues(alpha: 0.92),
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    );
  }

  Widget _modeBtn(String mode) {
    final selected = _modoOperacion == mode;
    final color = selected ? AppConstants.neonCyan : Colors.white54;
    return InkWell(
      onTap: () => setState(() {
        _modoOperacion = mode;
        if (mode == 'REGISTRAR') {
          _editingId = null;
          _idController.clear();
          _nombreController.clear();
          _imeiController.clear();
          _activo = true;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          mode,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, String label,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontFamily: 'Rajdhani',
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.28),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: AppConstants.neonCyan),
          ),
        ),
      ),
    );
  }

  Widget _drop({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontFamily: 'Rajdhani',
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.28),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF07131F),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _actionBtn(
      String label, Color color, FutureOr<void> Function() onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _oficialDropOptional({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Obx(() {
      final oficiales = _dashboard.oficiales.toList();
      final validValues = oficiales.map((o) => o.idOficial).toSet();
      final safeValue =
          (value != null && validValues.contains(value)) ? value : null;

      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontFamily: 'Rajdhani',
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.28),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: safeValue,
            isExpanded: true,
            dropdownColor: const Color(0xFF07131F),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('SELECCIONAR'),
              ),
              ...oficiales.map(
                (o) => DropdownMenuItem<String?>(
                  value: o.idOficial,
                  child: Text('${o.idOficial} · ${o.nombreOficial}'),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      );
    });
  }

  void _loadToForm(Oficial o) {
    setState(() {
      _editingId = o.idOficial;
      _idController.text = o.idOficial;
      _nombreController.text = o.nombreOficial;
      _grupo = o.grupo ?? 'ALFA';
      _grado = GradoAssets.displayName(o.grado);
      _imeiController.text = o.imei ?? '';
      _activo = o.activo;
      if (_modoOperacion == 'REGISTRAR') {
        _modoOperacion = 'MODIFICAR';
      }
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _idController.clear();
      _nombreController.clear();
      _imeiController.clear();
      _reoNuevoCodigoController.clear();
      _reoNombreController.clear();
      _reoDocumentoController.clear();
      _reoCoordsController.clear();
      _reoDireccionController.clear();
      _reoTelefonoController.clear();
      _reoObsController.clear();
      _grupo = 'ALFA';
      _grado = GradoAssets.defaultGrade;
      _activo = true;
      _registrarReoNuevo = false;
    });
  }

  Future<void> _register() async {
    final id = _idController.text.trim();
    final nombre = _nombreController.text.trim();
    if (id.isEmpty || nombre.isEmpty) {
      _msg('ID y nombre son obligatorios', isError: true);
      return;
    }
    final reoCodigo = _reoNuevoCodigoController.text.trim();
    if (_registrarReoNuevo) {
      if (reoCodigo.isEmpty || _reoNombreController.text.trim().isEmpty) {
        _msg(
            'Para registrar reo nuevo: codigo y nombre del reo son obligatorios',
            isError: true);
        return;
      }
    }

    await _confirmPinAndRun(() async {
      final ok = await _dashboard.registrarOficial(
        Oficial(
          idOficial: id,
          nombreOficial: nombre,
          grupo: _grupo,
          grado: _grado,
          reoAsignado: _registrarReoNuevo ? reoCodigo : null,
          imei: _imeiController.text.trim().isEmpty
              ? null
              : _imeiController.text.trim(),
          activo: _activo,
        ),
      );
      if (ok) {
        bool reoOk = true;
        if (_registrarReoNuevo) {
          reoOk = await _dashboard.registrarReo({
            'codigo_reo': reoCodigo,
            'nombre_completo': _reoNombreController.text.trim(),
            'documento_identidad': _reoDocumentoController.text.trim().isEmpty
                ? null
                : _reoDocumentoController.text.trim(),
            'coordenadas_casa': _reoCoordsController.text.trim().isEmpty
                ? null
                : _reoCoordsController.text.trim(),
            'direccion_casa': _reoDireccionController.text.trim().isEmpty
                ? null
                : _reoDireccionController.text.trim(),
            'telefono': _reoTelefonoController.text.trim().isEmpty
                ? null
                : _reoTelefonoController.text.trim(),
            'oficial_asignado': id,
            'observaciones': _reoObsController.text.trim().isEmpty
                ? null
                : _reoObsController.text.trim(),
          });
        }
        if (!reoOk) {
          _msg('Oficial registrado, pero no se pudo registrar el reo',
              isError: true);
          return;
        }
        _msg('Oficial registrado');
        _clearForm();
      } else {
        _msg('No se pudo registrar', isError: true);
      }
    });
  }

  Future<void> _update() async {
    final id = _editingId ?? _idController.text.trim();
    if (id.isEmpty) {
      _msg('Selecciona un oficial para actualizar', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.actualizarOficial(
        idOficial: id,
        data: {
          'nombre_oficial': _nombreController.text.trim(),
          'grupo': _grupo,
          'grado': _grado,
          'imei': _imeiController.text.trim().isEmpty
              ? null
              : _imeiController.text.trim(),
          'activo': _activo,
        },
      );
      _msg(ok ? 'Oficial actualizado' : 'No se pudo actualizar', isError: !ok);
    });
  }

  Future<void> _deactivate() async {
    if (_editingId == null) {
      _msg('Selecciona un oficial para eliminar', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.desactivarOficial(_editingId!);
      _msg(ok ? 'Oficial desactivado' : 'No se pudo desactivar', isError: !ok);
    });
  }

  Future<void> _activate() async {
    if (_editingId == null) {
      _msg('Selecciona un oficial para reactivar', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.activarOficial(_editingId!);
      _msg(ok ? 'Oficial reactivado' : 'No se pudo reactivar', isError: !ok);
    });
  }

  Future<void> _batchGroup() async {
    if (_selectedIds.isEmpty) {
      _msg('Selecciona al menos un oficial', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.actualizarOficialesMasivo(
        ids: _selectedIds.toList(),
        grupo: _batchGrupo,
      );
      _msg(ok ? 'Grupo actualizado masivamente' : 'No se pudo aplicar',
          isError: !ok);
    });
  }

  Future<void> _batchDeactivate() async {
    if (_selectedIds.isEmpty) {
      _msg('Selecciona al menos un oficial', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.actualizarOficialesMasivo(
        ids: _selectedIds.toList(),
        activo: false,
      );
      _msg(ok ? 'Seleccion desactivada' : 'No se pudo desactivar',
          isError: !ok);
    });
  }

  Future<void> _batchActivate() async {
    if (_selectedIds.isEmpty) {
      _msg('Selecciona al menos un oficial', isError: true);
      return;
    }
    await _confirmPinAndRun(() async {
      final ok = await _dashboard.actualizarOficialesMasivo(
        ids: _selectedIds.toList(),
        activo: true,
      );
      _msg(ok ? 'Seleccion activada' : 'No se pudo activar', isError: !ok);
    });
  }

  Future<void> _applyReplacement() async {
    final salienteId = _reemplazoSalienteId;
    final entranteId = _reemplazoEntranteId;

    if (salienteId == null || entranteId == null) {
      _msg('Selecciona oficial saliente y entrante', isError: true);
      return;
    }
    if (salienteId == entranteId) {
      _msg('Saliente y entrante no pueden ser el mismo', isError: true);
      return;
    }

    final saliente =
        _dashboard.oficiales.firstWhereOrNull((o) => o.idOficial == salienteId);
    final entrante =
        _dashboard.oficiales.firstWhereOrNull((o) => o.idOficial == entranteId);
    if (saliente == null || entrante == null) {
      _msg('No se pudo validar oficiales seleccionados', isError: true);
      return;
    }

    await _confirmPinAndRun(() async {
      final okEntrante = await _dashboard.actualizarOficial(
        idOficial: entrante.idOficial,
        data: {
          'grupo': saliente.grupo,
          'reo_asignado': saliente.reoAsignado,
          'activo': true
        },
      );
      final okSaliente = await _dashboard.actualizarOficial(
        idOficial: saliente.idOficial,
        data: {'reo_asignado': null, 'activo': false},
      );
      if (okEntrante && okSaliente) {
        _msg('Reemplazo aplicado correctamente');
        setState(() {
          _reemplazoSalienteId = null;
          _reemplazoEntranteId = null;
        });
      } else {
        _msg('No se pudo aplicar el reemplazo', isError: true);
      }
    });
  }

  Future<void> _confirmPinAndRun(Future<void> Function() action) async {
    bool authorized = false;
    await Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppConstants.neonCyan.withValues(alpha: 0.45)),
          ),
          child: PinPad(
            title: 'CONFIRMAR CAMBIO',
            onComplete: (pin) async {
              final ok = await _auth.verifyCurrentAdminPin(pin);
              if (ok) {
                authorized = true;
                Get.back();
              } else {
                final lockSeconds = _auth.pinLockRemainingSeconds;
                final msg = lockSeconds > 0
                    ? 'PIN bloqueado temporalmente ($lockSeconds s)'
                    : 'PIN incorrecto';
                _msg(msg, isError: true);
              }
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );

    if (!authorized) return;
    await action();
  }

  void _msg(String text, {bool isError = false}) {
    Get.snackbar(
      isError ? 'ERROR' : 'SISTEMA',
      text,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: (isError ? Colors.redAccent : AppConstants.neonCyan)
          .withValues(alpha: 0.25),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}
