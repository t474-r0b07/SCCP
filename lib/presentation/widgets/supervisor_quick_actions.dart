import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/radio_rtc_engine.dart';
import '../../core/services/radio_rtc_signaling.dart';
import '../../data/models/oficial_model.dart';
import '../../data/models/radio_message_model.dart';
import '../controllers/dashboard_controller.dart';
import '../views/partes_view.dart';

Future<void> showSupervisorPartesDialog({
  required DashboardController controller,
  required String supervisorName,
}) async {
  final razonController = TextEditingController();
  final oficialesActivos = _oficialesActivosDelTurno(controller);
  final errorByOficial = _operationalErrorScoreByOficial(controller);
  final oficialesOrdenadosPartes =
      _sortOficialesForPartes(controller, oficialesActivos, errorByOficial);
  String? selectedOficialId = oficialesOrdenadosPartes.isNotEmpty
      ? oficialesOrdenadosPartes.first.idOficial
      : null;

  await Get.dialog(
    StatefulBuilder(
      builder: (context, setState) {
        final media = MediaQuery.of(context).size;
        final mobileDialog = media.width < 860 || media.shortestSide < 640;
        final compactDialog =
            mobileDialog || media.width < 920 || media.shortestSide < 700;
        final dialogWidth = (mobileDialog
                ? media.width
                : (compactDialog ? media.width - 12 : 860))
            .clamp(260.0, 860.0);
        final dialogHeight = mobileDialog
            ? media.height
            : (compactDialog ? media.height * 0.94 : 560)
                .clamp(420.0, 760.0)
                .toDouble();

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobileDialog ? 0 : (compactDialog ? 6 : 24),
            vertical: mobileDialog ? 0 : (compactDialog ? 10 : 24),
          ),
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: mobileDialog ? 0 : 24,
              vertical: mobileDialog ? 0 : 24,
            ),
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: dialogWidth.toDouble(),
              height: dialogHeight.toDouble(),
              child: SafeArea(
                top: mobileDialog,
                bottom: mobileDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppConstants.darkBg.withValues(alpha: 0.98),
                    borderRadius: mobileDialog
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    border: Border.all(
                      color: AppConstants.neonPink.withValues(alpha: 0.75),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDialogHeader(
                        icon: Icons.flash_on_rounded,
                        title: 'PARTES SORPRESA - SUPERVISIÓN',
                        color: AppConstants.neonPink,
                        compact: compactDialog,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compactDialog ? 12 : 16,
                          compactDialog ? 10 : 14,
                          compactDialog ? 12 : 16,
                          8,
                        ),
                        child: Column(
                          children: [
                            if (compactDialog) ...[
                              _buildOficialDropdown(
                                label: 'Oficial',
                                value: selectedOficialId,
                                color: AppConstants.neonPink,
                                oficialesActivos: oficialesOrdenadosPartes,
                                errorByOficial: errorByOficial,
                                onChanged: (value) {
                                  setState(() => selectedOficialId = value);
                                },
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppConstants.neonPink,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: () async {
                                    final target = selectedOficialId;
                                    final reason = razonController.text.trim();
                                    if (target == null || reason.isEmpty) {
                                      Get.snackbar(
                                        'Partes Sorpresa',
                                        'Selecciona oficial y razón táctica.',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                      return;
                                    }

                                    final ok =
                                        await controller.solicitarParteDirecto(
                                      idOficial: target,
                                      supervisorNombre: supervisorName,
                                      razon: reason,
                                    );
                                    if (!ok) {
                                      Get.snackbar(
                                        'Partes Sorpresa',
                                        'No se pudo crear el parte.',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                      return;
                                    }

                                    razonController.clear();
                                    Get.snackbar(
                                      'Partes Sorpresa',
                                      'Solicitud directa enviada al oficial $target.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                                  icon:
                                      const Icon(Icons.send_rounded, size: 17),
                                  label: const Text('Activar'),
                                ),
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildOficialDropdown(
                                      label: 'Oficial',
                                      value: selectedOficialId,
                                      color: AppConstants.neonPink,
                                      oficialesActivos:
                                          oficialesOrdenadosPartes,
                                      errorByOficial: errorByOficial,
                                      onChanged: (value) {
                                        setState(
                                            () => selectedOficialId = value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppConstants.neonPink,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () async {
                                      final target = selectedOficialId;
                                      final reason =
                                          razonController.text.trim();
                                      if (target == null || reason.isEmpty) {
                                        Get.snackbar(
                                          'Partes Sorpresa',
                                          'Selecciona oficial y razón táctica.',
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                        return;
                                      }

                                      final ok = await controller
                                          .solicitarParteDirecto(
                                        idOficial: target,
                                        supervisorNombre: supervisorName,
                                        razon: reason,
                                      );
                                      if (!ok) {
                                        Get.snackbar(
                                          'Partes Sorpresa',
                                          'No se pudo crear el parte.',
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                        return;
                                      }

                                      razonController.clear();
                                      Get.snackbar(
                                        'Partes Sorpresa',
                                        'Solicitud directa enviada al oficial $target.',
                                        snackPosition: SnackPosition.BOTTOM,
                                      );
                                    },
                                    icon: const Icon(Icons.send_rounded,
                                        size: 17),
                                    label: const Text('Activar'),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: razonController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Rajdhani',
                              ),
                              decoration: _inputDecoration(
                                label: 'Razón táctica',
                                color: AppConstants.neonPink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const PartesView(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
    barrierDismissible: true,
  );

  razonController.dispose();
}

Future<void> showSupervisorRadioDialog({
  required DashboardController controller,
}) async {
  final messageController = TextEditingController();
  final callResumenController = TextEditingController();
  final oficialesActivos = _oficialesActivosDelTurno(controller);
  final errorByOficialInicial = _operationalErrorScoreByOficial(controller);
  final unreadByOficialInicial = _radioUnreadByOficial(controller);
  final lastMessageByOficialInicial = _radioLastMessageAtByOficial(controller);
  final oficialesOrdenadosInicial = _sortOficialesByUnread(
    oficialesActivos,
    unreadByOficialInicial,
    lastMessageByOficialInicial,
    errorByOficialInicial,
  );
  String? selectedOficialId = oficialesOrdenadosInicial.isNotEmpty
      ? oficialesOrdenadosInicial.first.idOficial
      : null;
  bool isSending = false;
  String? activeCallId;
  String? activeCallOficialId;
  DateTime? callStartedAt;
  String? rtcStatus;
  bool rtcConnected = false;
  RadioRtcEngine? rtcEngine;
  String? rtcPeerUser;
  final handledRtcMessages = <String>{};
  StateSetter? dialogSetState;

  DateTime? parseCallStart(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  void safeSetState(VoidCallback fn) {
    final setter = dialogSetState;
    if (setter == null) return;
    try {
      setter(fn);
    } catch (_) {}
  }

  Future<void> closeRtcEngine({bool clearStatus = false}) async {
    await rtcEngine?.close();
    rtcEngine = null;
    rtcPeerUser = null;
    rtcConnected = false;
    if (clearStatus) {
      rtcStatus = null;
    }
  }

  Future<bool> sendRtcSignal({
    required String idOficial,
    required RadioRtcSignal signal,
  }) async {
    return controller.repository.sendRadioMessage(
      idOficial: idOficial,
      fromUser: signal.fromUser,
      toUser: signal.toUser,
      message: signal.encode(),
      type: 'RADIO',
    );
  }

  Future<void> ensureRtcEngine({
    required String callId,
    required String idOficial,
    required String peerUser,
  }) async {
    if (rtcEngine != null &&
        rtcPeerUser == peerUser &&
        activeCallId == callId) {
      return;
    }

    await closeRtcEngine();
    rtcPeerUser = peerUser;
    rtcEngine = RadioRtcEngine(
      onLocalIceCandidate: (candidate) {
        final currentCall = activeCallId;
        final target = activeCallOficialId ?? selectedOficialId;
        if (currentCall == null || target == null || rtcPeerUser == null) {
          return;
        }
        unawaited(
          sendRtcSignal(
            idOficial: target,
            signal: RadioRtcSignal(
              action: RadioRtcSignal.ice,
              callId: currentCall,
              fromUser: 'SUPERVISOR',
              toUser: rtcPeerUser!,
              data: RadioRtcEngine.serializeIceCandidate(candidate),
            ),
          ),
        );
      },
      onConnectionState: (state) {
        final raw = state.toString().toUpperCase();
        safeSetState(() {
          if (raw.contains('CONNECTED')) {
            rtcConnected = true;
            rtcStatus = 'AUDIO CONECTADO';
          } else if (raw.contains('CONNECTING')) {
            rtcStatus = 'CONECTANDO AUDIO...';
          } else if (raw.contains('FAILED')) {
            rtcConnected = false;
            rtcStatus = 'FALLO DE CONEXION';
          } else if (raw.contains('DISCONNECTED') || raw.contains('CLOSED')) {
            rtcConnected = false;
            rtcStatus = 'LLAMADA FINALIZADA';
          }
        });
      },
    );
    await rtcEngine!.initialize();
    safeSetState(() {
      rtcStatus = 'NEGOCIANDO AUDIO...';
    });
  }

  Future<void> processRtcSignals(List<RadioMessage> rows) async {
    final sorted = rows.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (final msg in sorted) {
      if (handledRtcMessages.contains(msg.idMensaje)) continue;
      final signal = RadioRtcSignal.tryParse(msg.mensaje);
      if (signal == null) continue;
      handledRtcMessages.add(msg.idMensaje);

      if (signal.toUser.trim().toUpperCase() != 'SUPERVISOR') continue;
      if (activeCallId == null || signal.callId != activeCallId) continue;

      switch (signal.action) {
        case RadioRtcSignal.answer:
          await rtcEngine?.applyRemoteAnswer(signal.data);
          safeSetState(() {
            rtcStatus = 'RESPUESTA RECIBIDA';
          });
          break;
        case RadioRtcSignal.ice:
          await rtcEngine?.addRemoteIceCandidate(signal.data);
          break;
        case RadioRtcSignal.hangup:
        case RadioRtcSignal.reject:
          final target = activeCallOficialId;
          final callId = activeCallId;
          if (target != null && callId != null) {
            await controller.repository.endRadioCall(
              callId: callId,
              idOficial: target,
              fromUser: 'SUPERVISOR',
              toUser: target,
              resumen: signal.action == RadioRtcSignal.reject
                  ? 'RECHAZADA POR OFICIAL'
                  : 'FINALIZADA POR OFICIAL',
            );
          }
          await closeRtcEngine();
          safeSetState(() {
            activeCallId = null;
            activeCallOficialId = null;
            callStartedAt = null;
            rtcStatus = signal.action == RadioRtcSignal.reject
                ? 'RECHAZADA POR OFICIAL'
                : 'FINALIZADA POR OFICIAL';
          });
          break;
      }
    }
  }

  if (selectedOficialId != null) {
    final active = await controller.repository.getActiveRadioCall(
      idOficial: selectedOficialId,
    );
    if (active != null) {
      activeCallId = (active['id_llamada'] ?? '').toString();
      activeCallOficialId =
          (active['id_oficial'] ?? selectedOficialId).toString();
      callStartedAt = parseCallStart(active['inicio_llamada']);
      if (activeCallId?.isEmpty ?? true) {
        activeCallId = null;
        activeCallOficialId = null;
      }
    }
    await controller.markSupervisorRadioInboxAsRead(
        oficialId: selectedOficialId);
  }

  await Get.dialog(
    StatefulBuilder(
      builder: (context, setState) {
        dialogSetState = setState;
        final errorByOficial = _operationalErrorScoreByOficial(controller);
        final unreadByOficial = _radioUnreadByOficial(controller);
        final lastMessageByOficial = _radioLastMessageAtByOficial(controller);
        final oficialesOrdenados = _sortOficialesByUnread(
          oficialesActivos,
          unreadByOficial,
          lastMessageByOficial,
          errorByOficial,
        );
        final stream = controller.repository
            .watchRadioMessages(idOficial: selectedOficialId);

        Future<void> sendMessage(String type, String body) async {
          final target = selectedOficialId;
          if (target == null || body.trim().isEmpty) return;
          setState(() => isSending = true);
          final ok = await controller.repository.sendRadioMessage(
            idOficial: target,
            fromUser: 'SUPERVISOR',
            toUser: target,
            message: body,
            type: type,
          );
          setState(() => isSending = false);
          if (ok && type == 'RADIO') {
            messageController.clear();
            await controller.markSupervisorRadioInboxAsRead(oficialId: target);
          }
          if (!ok) {
            Get.snackbar(
              'Radio',
              'No se pudo enviar el mensaje.',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        }

        Future<void> startCall() async {
          final target = selectedOficialId;
          if (target == null || activeCallId != null) return;
          setState(() => isSending = true);
          final callId = await controller.repository.startRadioCall(
            idOficial: target,
            fromUser: 'SUPERVISOR',
            toUser: target,
          );
          final active = callId == null
              ? null
              : await controller.repository
                  .getActiveRadioCall(idOficial: target);
          setState(() {
            isSending = false;
            if (callId != null) {
              activeCallId = callId;
              activeCallOficialId = target;
              callStartedAt =
                  parseCallStart(active?['inicio_llamada']) ?? DateTime.now();
              rtcStatus = 'INICIANDO RTC...';
            }
          });
          if (callId == null) {
            Get.snackbar(
              'Radio',
              'No se pudo iniciar el contacto de radio.',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }

          try {
            await ensureRtcEngine(
              callId: callId,
              idOficial: target,
              peerUser: target,
            );
            final offer = await rtcEngine!.createOffer();
            final sent = await sendRtcSignal(
              idOficial: target,
              signal: RadioRtcSignal(
                action: RadioRtcSignal.offer,
                callId: callId,
                fromUser: 'SUPERVISOR',
                toUser: target,
                data: offer,
              ),
            );
            if (!sent) {
              await closeRtcEngine();
              await controller.repository.endRadioCall(
                callId: callId,
                idOficial: target,
                fromUser: 'SUPERVISOR',
                toUser: target,
                resumen: 'FALLO_ENVIO_OFFER',
              );
              setState(() {
                activeCallId = null;
                activeCallOficialId = null;
                callStartedAt = null;
                rtcStatus = 'FALLO EN ENVIO RTC';
              });
              Get.snackbar(
                'Radio',
                'No se pudo enviar la señal de llamada RTC.',
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
            setState(() {
              rtcStatus = 'ESPERANDO RESPUESTA DEL OFICIAL...';
            });
          } catch (_) {
            await closeRtcEngine();
            await controller.repository.endRadioCall(
              callId: callId,
              idOficial: target,
              fromUser: 'SUPERVISOR',
              toUser: target,
              resumen: 'FALLO_NEGOCIACION_RTC',
            );
            setState(() {
              activeCallId = null;
              activeCallOficialId = null;
              callStartedAt = null;
              rtcStatus = 'FALLO DE NEGOCIACION RTC';
            });
            Get.snackbar(
              'Radio',
              'No se pudo completar la llamada RTC.',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        }

        Future<void> endCall() async {
          final target = activeCallOficialId ?? selectedOficialId;
          final callId = activeCallId;
          if (target == null || callId == null) return;

          setState(() => isSending = true);
          await sendRtcSignal(
            idOficial: target,
            signal: RadioRtcSignal(
              action: RadioRtcSignal.hangup,
              callId: callId,
              fromUser: 'SUPERVISOR',
              toUser: target,
            ),
          );
          await closeRtcEngine();
          final ok = await controller.repository.endRadioCall(
            callId: callId,
            idOficial: target,
            fromUser: 'SUPERVISOR',
            toUser: target,
            resumen: callResumenController.text.trim(),
          );
          setState(() {
            isSending = false;
            if (ok) {
              activeCallId = null;
              activeCallOficialId = null;
              callStartedAt = null;
              rtcStatus = 'LLAMADA FINALIZADA';
              callResumenController.clear();
            }
          });
          if (!ok) {
            Get.snackbar(
              'Radio',
              'No se pudo cerrar el contacto de radio.',
              snackPosition: SnackPosition.BOTTOM,
            );
          }
        }

        String radioActorLabel(String raw) {
          final clean = raw.trim();
          if (clean.isEmpty) return 'USUARIO';
          if (clean.toUpperCase() == 'SUPERVISOR') return 'SUPERVISOR';
          return 'OFICIAL';
        }

        String oficialNameById(String id) {
          final oficial =
              controller.oficiales.firstWhereOrNull((o) => o.idOficial == id);
          if (oficial == null) return '';
          return oficial.nombreOficial.trim();
        }

        final media = MediaQuery.of(context).size;
        final compactDialog = media.width < 1080 || media.shortestSide < 760;
        final mobileDialog = media.width < 860 || media.shortestSide < 640;
        final dialogWidth = (mobileDialog
                ? media.width
                : (compactDialog ? media.width * 0.95 : 980))
            .clamp(260.0, 980.0);
        final dialogHeight = mobileDialog
            ? media.height
            : (compactDialog ? media.height * 0.92 : 680)
                .clamp(500.0, 760.0)
                .toDouble();

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobileDialog ? 0 : 24,
            vertical: mobileDialog ? 0 : 20,
          ),
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: mobileDialog ? 0 : 24,
              vertical: mobileDialog ? 0 : 20,
            ),
            backgroundColor: Colors.transparent,
            child: SizedBox(
              width: dialogWidth.toDouble(),
              height: dialogHeight.toDouble(),
              child: SafeArea(
                top: mobileDialog,
                bottom: mobileDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppConstants.darkBg.withValues(alpha: 0.98),
                    borderRadius: mobileDialog
                        ? BorderRadius.zero
                        : BorderRadius.circular(12),
                    border: Border.all(
                      color: AppConstants.neonOrange.withValues(alpha: 0.8),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDialogHeader(
                        icon: Icons.multitrack_audio_rounded,
                        title: 'RADIO OPERATIVA - SUPERVISOR',
                        color: AppConstants.neonOrange,
                        compact: mobileDialog,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobileDialog ? 12 : 16,
                          mobileDialog ? 10 : 14,
                          mobileDialog ? 12 : 16,
                          8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildOficialDropdown(
                                label: 'Canal oficial',
                                value: selectedOficialId,
                                color: AppConstants.neonOrange,
                                oficialesActivos: oficialesOrdenados,
                                unreadByOficial: unreadByOficial,
                                errorByOficial: errorByOficial,
                                onChanged: (value) async {
                                  if (activeCallId != null &&
                                      value != activeCallOficialId) {
                                    Get.snackbar(
                                      'Radio',
                                      'Finaliza el contacto activo antes de cambiar de canal.',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    return;
                                  }
                                  setState(() {
                                    selectedOficialId = value;
                                    activeCallId = null;
                                    activeCallOficialId = null;
                                    callStartedAt = null;
                                    rtcStatus = null;
                                  });
                                  if (value == null) return;
                                  await controller
                                      .markSupervisorRadioInboxAsRead(
                                    oficialId: value,
                                  );
                                  await closeRtcEngine(clearStatus: true);
                                  final active = await controller.repository
                                      .getActiveRadioCall(idOficial: value);
                                  if (selectedOficialId != value) return;
                                  setState(() {
                                    if (active == null) return;
                                    final resolvedId =
                                        (active['id_llamada'] ?? '').toString();
                                    if (resolvedId.isEmpty) return;
                                    activeCallId = resolvedId;
                                    activeCallOficialId =
                                        (active['id_oficial'] ?? value)
                                            .toString();
                                    callStartedAt = parseCallStart(
                                      active['inicio_llamada'],
                                    );
                                    rtcStatus = activeCallId == null
                                        ? null
                                        : 'SESION ACTIVA (REQUIERE REABRIR AUDIO)';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobileDialog ? 12 : 16,
                          0,
                          mobileDialog ? 12 : 16,
                          10,
                        ),
                        child: mobileDialog
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: activeCallId == null
                                            ? Colors.white24
                                            : AppConstants.neonCyan
                                                .withValues(alpha: 0.65),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      activeCallId == null
                                          ? 'CONTACTO RADIO: SIN SESION ACTIVA'
                                          : 'CONTACTO RTC ${rtcConnected ? "ACTIVO" : "NEGOCIANDO"} · INICIO ${callStartedAt?.hour.toString().padLeft(2, '0')}:${callStartedAt?.minute.toString().padLeft(2, '0')}${rtcStatus == null ? "" : " · $rtcStatus"}',
                                      style: TextStyle(
                                        color: activeCallId == null
                                            ? Colors.white70
                                            : AppConstants.neonCyan,
                                        fontFamily: 'Orbitron',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppConstants.neonCyan,
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed:
                                              selectedOficialId == null ||
                                                      isSending ||
                                                      activeCallId != null
                                                  ? null
                                                  : startCall,
                                          icon: const Icon(
                                            Icons.wifi_calling_3_rounded,
                                            size: 17,
                                          ),
                                          label: const Text('Abrir contacto'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppConstants.warningRed,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed:
                                              selectedOficialId == null ||
                                                      isSending ||
                                                      activeCallId == null
                                                  ? null
                                                  : endCall,
                                          icon: const Icon(
                                            Icons.call_end_rounded,
                                            size: 17,
                                          ),
                                          label: const Text('Cerrar contacto'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: activeCallId == null
                                              ? Colors.white24
                                              : AppConstants.neonCyan
                                                  .withValues(alpha: 0.65),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        activeCallId == null
                                            ? 'CONTACTO RADIO: SIN SESION ACTIVA'
                                            : 'CONTACTO RTC ${rtcConnected ? "ACTIVO" : "NEGOCIANDO"} · INICIO ${callStartedAt?.hour.toString().padLeft(2, '0')}:${callStartedAt?.minute.toString().padLeft(2, '0')}${rtcStatus == null ? "" : " · $rtcStatus"}',
                                        style: TextStyle(
                                          color: activeCallId == null
                                              ? Colors.white70
                                              : AppConstants.neonCyan,
                                          fontFamily: 'Orbitron',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppConstants.neonCyan,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: selectedOficialId == null ||
                                            isSending ||
                                            activeCallId != null
                                        ? null
                                        : startCall,
                                    icon: const Icon(
                                      Icons.wifi_calling_3_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Abrir contacto'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppConstants.warningRed,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: selectedOficialId == null ||
                                            isSending ||
                                            activeCallId == null
                                        ? null
                                        : endCall,
                                    icon: const Icon(Icons.call_end_rounded,
                                        size: 17),
                                    label: const Text('Cerrar contacto'),
                                  ),
                                ],
                              ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: StreamBuilder<List<RadioMessage>>(
                            stream: stream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Radio no disponible: ${snapshot.error}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontFamily: 'Rajdhani',
                                    ),
                                  ),
                                );
                              }
                              final rows =
                                  snapshot.data ?? const <RadioMessage>[];
                              unawaited(processRtcSignals(rows));
                              final visibleRows = rows
                                  .where(
                                    (msg) => !RadioRtcSignal.isRtcPayload(
                                        msg.mensaje),
                                  )
                                  .toList();
                              if (visibleRows.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Sin tráfico en el canal seleccionado',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontFamily: 'Rajdhani',
                                    ),
                                  ),
                                );
                              }
                              final items = visibleRows
                                ..sort((a, b) {
                                  final timeCmp =
                                      b.timestamp.compareTo(a.timestamp);
                                  if (timeCmp != 0) return timeCmp;
                                  final unreadA = a.isIncomingForSupervisor &&
                                      a.estado.trim().toUpperCase() != 'LEIDO';
                                  final unreadB = b.isIncomingForSupervisor &&
                                      b.estado.trim().toUpperCase() != 'LEIDO';
                                  if (unreadA != unreadB) {
                                    return unreadB ? 1 : -1;
                                  }
                                  return b.idMensaje.compareTo(a.idMensaje);
                                });
                              return ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final msg = items[index];
                                  final incoming = msg.isIncomingForSupervisor;
                                  final oficialName =
                                      oficialNameById(msg.idOficial);
                                  final actorLabel = incoming
                                      ? (oficialName.isEmpty
                                          ? radioActorLabel(msg.deUsuario)
                                          : oficialName)
                                      : 'SUPERVISOR';
                                  final unreadIncoming = incoming &&
                                      msg.estado.trim().toUpperCase() !=
                                          'LEIDO';
                                  final type = msg.tipo.trim().toUpperCase();
                                  final isCallEvent = type == 'CALL_START' ||
                                      type == 'CALL_END';
                                  final bubbleColor = incoming
                                      ? AppConstants.neonCyan
                                          .withValues(alpha: 0.18)
                                      : isCallEvent
                                          ? AppConstants.warningRed
                                              .withValues(alpha: 0.2)
                                          : AppConstants.neonOrange
                                              .withValues(alpha: 0.18);
                                  final borderColor = incoming
                                      ? AppConstants.neonCyan
                                          .withValues(alpha: 0.45)
                                      : AppConstants.neonOrange
                                          .withValues(alpha: 0.45);

                                  return Align(
                                    alignment: incoming
                                        ? Alignment.centerLeft
                                        : Alignment.centerRight,
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: (mobileDialog
                                                ? dialogWidth * 0.9
                                                : 500.0)
                                            .clamp(180.0, 500.0)
                                            .toDouble(),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bubbleColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: incoming
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            actorLabel,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (unreadIncoming) ...[
                                            const SizedBox(height: 3),
                                            const Text(
                                              'NUEVO',
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontFamily: 'Orbitron',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            msg.mensaje,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Rajdhani',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontFamily: 'Orbitron',
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          mobileDialog ? 12 : 16,
                          0,
                          mobileDialog ? 12 : 16,
                          14,
                        ),
                        child: mobileDialog
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: callResumenController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Rajdhani',
                                    ),
                                    decoration: _inputDecoration(
                                      label: 'Resumen de contacto (opcional)',
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: messageController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Rajdhani',
                                    ),
                                    decoration: _inputDecoration(
                                      label: 'Mensaje por radio',
                                      color: AppConstants.neonOrange,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppConstants.neonOrange,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: selectedOficialId == null ||
                                              isSending
                                          ? null
                                          : () => sendMessage(
                                                'RADIO',
                                                messageController.text.trim(),
                                              ),
                                      icon: const Icon(Icons.send_rounded,
                                          size: 17),
                                      label: const Text('Enviar'),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: callResumenController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Rajdhani',
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Resumen de contacto (opcional)',
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: messageController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Rajdhani',
                                      ),
                                      decoration: _inputDecoration(
                                        label: 'Mensaje por radio',
                                        color: AppConstants.neonOrange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppConstants.neonOrange,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed:
                                        selectedOficialId == null || isSending
                                            ? null
                                            : () => sendMessage(
                                                  'RADIO',
                                                  messageController.text.trim(),
                                                ),
                                    icon: const Icon(Icons.send_rounded,
                                        size: 17),
                                    label: const Text('Enviar'),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
    barrierDismissible: true,
  );

  final targetOnClose = activeCallOficialId ?? selectedOficialId;
  if (activeCallId != null && targetOnClose != null) {
    await sendRtcSignal(
      idOficial: targetOnClose,
      signal: RadioRtcSignal(
        action: RadioRtcSignal.hangup,
        callId: activeCallId!,
        fromUser: 'SUPERVISOR',
        toUser: targetOnClose,
      ),
    );
    await controller.repository.endRadioCall(
      callId: activeCallId!,
      idOficial: targetOnClose,
      fromUser: 'SUPERVISOR',
      toUser: targetOnClose,
      resumen: 'CIERRE DE VENTANA RADIO',
    );
  }
  if (selectedOficialId != null) {
    await controller.markSupervisorRadioInboxAsRead(
        oficialId: selectedOficialId);
  }
  await closeRtcEngine(clearStatus: true);

  messageController.dispose();
  callResumenController.dispose();
}

List<Oficial> _oficialesActivosDelTurno(DashboardController controller) {
  final turno = controller.currentGroup.value.toUpperCase();
  return controller.oficiales.where((o) {
    if (!o.activo) return false;
    return (o.grupo ?? '').toUpperCase() == turno;
  }).toList();
}

Widget _buildDialogHeader({
  required IconData icon,
  required String title,
  required Color color,
  bool compact = false,
}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 18,
      vertical: compact ? 10 : 14,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: compact ? 18 : 22),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11.5 : 13,
              letterSpacing: compact ? 0.6 : 1.1,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Get.back(),
          visualDensity:
              compact ? VisualDensity.compact : VisualDensity.standard,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          icon: const Icon(Icons.close, color: Colors.white60),
        ),
      ],
    ),
  );
}

Widget _buildOficialDropdown({
  required String label,
  required String? value,
  required Color color,
  required List<Oficial> oficialesActivos,
  Map<String, int> unreadByOficial = const <String, int>{},
  Map<String, int> errorByOficial = const <String, int>{},
  required ValueChanged<String?> onChanged,
}) {
  final hasSelected =
      value != null && oficialesActivos.any((o) => o.idOficial == value);
  final safeValue = hasSelected ? value : null;

  return DropdownButtonFormField<String>(
    initialValue: safeValue,
    isExpanded: true,
    decoration: _inputDecoration(label: label, color: color),
    dropdownColor: AppConstants.darkPanel,
    selectedItemBuilder: (_) => oficialesActivos
        .map(
          (o) => Text(
            '${o.idOficial} - ${o.nombreOficial}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
            ),
          ),
        )
        .toList(),
    items: oficialesActivos
        .map(
          (o) => DropdownMenuItem<String>(
            value: o.idOficial,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${o.idOficial} - ${o.nombreOficial}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Rajdhani',
                    ),
                  ),
                ),
                if ((unreadByOficial[o.idOficial] ?? 0) > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${unreadByOficial[o.idOficial]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                if ((errorByOficial[o.idOficial] ?? 0) > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.warningRed.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${errorByOficial[o.idOficial]}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        )
        .toList(),
    onChanged: oficialesActivos.isEmpty ? null : onChanged,
  );
}

Map<String, int> _radioUnreadByOficial(DashboardController controller) {
  final counts = <String, int>{};
  for (final msg in controller.radioInboxSupervisor) {
    final from = msg.deUsuario.trim().toUpperCase();
    final estado = msg.estado.trim().toUpperCase();
    if (RadioRtcSignal.isRtcPayload(msg.mensaje)) continue;
    if (from == 'SUPERVISOR' || estado == 'LEIDO') continue;
    final id = msg.idOficial.trim();
    if (id.isEmpty) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

List<Oficial> _sortOficialesByUnread(
  List<Oficial> source,
  Map<String, int> unreadByOficial,
  Map<String, DateTime> lastMessageByOficial,
  Map<String, int> errorByOficial,
) {
  final list = source.toList();
  list.sort((a, b) {
    final errorsA = errorByOficial[a.idOficial] ?? 0;
    final errorsB = errorByOficial[b.idOficial] ?? 0;
    if (errorsA != errorsB) return errorsB.compareTo(errorsA);

    final unreadA = unreadByOficial[a.idOficial] ?? 0;
    final unreadB = unreadByOficial[b.idOficial] ?? 0;
    if (unreadA != unreadB) return unreadB.compareTo(unreadA);
    final lastA = lastMessageByOficial[a.idOficial];
    final lastB = lastMessageByOficial[b.idOficial];
    if (lastA != null && lastB != null && !lastA.isAtSameMomentAs(lastB)) {
      return lastB.compareTo(lastA);
    }
    if (lastA != null && lastB == null) return -1;
    if (lastA == null && lastB != null) return 1;
    final idCmp = a.idOficial.compareTo(b.idOficial);
    if (idCmp != 0) return idCmp;
    return a.nombreOficial.compareTo(b.nombreOficial);
  });
  return list;
}

Map<String, DateTime> _radioLastMessageAtByOficial(
  DashboardController controller,
) {
  final last = <String, DateTime>{};
  for (final msg in controller.radioInboxSupervisor) {
    if (RadioRtcSignal.isRtcPayload(msg.mensaje)) continue;
    final id = msg.idOficial.trim();
    if (id.isEmpty) continue;
    final current = last[id];
    if (current == null || msg.timestamp.isAfter(current)) {
      last[id] = msg.timestamp;
    }
  }
  return last;
}

List<Oficial> _sortOficialesForPartes(
  DashboardController controller,
  List<Oficial> source,
  Map<String, int> errorScoreByOficial,
) {
  final pendingCountByOficial = <String, int>{};
  final lastPendingAtByOficial = <String, DateTime>{};

  for (final parte in controller.partesSorpresa) {
    final id = parte.idOficial.trim();
    if (id.isEmpty) continue;
    final estado = parte.estadoNormalized;
    final isPending =
        estado == 'NUEVO' || estado == 'PENDIENTE' || estado == 'LEIDO';
    if (!isPending) continue;
    pendingCountByOficial[id] = (pendingCountByOficial[id] ?? 0) + 1;
    final currentTs = lastPendingAtByOficial[id];
    if (currentTs == null || parte.timestamp.isAfter(currentTs)) {
      lastPendingAtByOficial[id] = parte.timestamp;
    }
  }

  final list = source.toList();
  list.sort((a, b) {
    final errA = errorScoreByOficial[a.idOficial] ?? 0;
    final errB = errorScoreByOficial[b.idOficial] ?? 0;
    if (errA != errB) return errB.compareTo(errA);

    final pendingA = pendingCountByOficial[a.idOficial] ?? 0;
    final pendingB = pendingCountByOficial[b.idOficial] ?? 0;
    if (pendingA != pendingB) return pendingB.compareTo(pendingA);

    final lastA = lastPendingAtByOficial[a.idOficial];
    final lastB = lastPendingAtByOficial[b.idOficial];
    if (lastA != null && lastB != null && !lastA.isAtSameMomentAs(lastB)) {
      return lastB.compareTo(lastA);
    }
    if (lastA != null && lastB == null) return -1;
    if (lastA == null && lastB != null) return 1;

    final idCmp = a.idOficial.compareTo(b.idOficial);
    if (idCmp != 0) return idCmp;
    return a.nombreOficial.compareTo(b.nombreOficial);
  });
  return list;
}

Map<String, int> _operationalErrorScoreByOficial(
  DashboardController controller,
) {
  final score = <String, int>{};

  for (final alerta in controller.alertasEpisodiosActivosDelTurno) {
    final id = (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '')
        .toString()
        .trim();
    if (id.isEmpty) continue;
    score[id] = (score[id] ?? 0) + 1;
  }

  for (final inc in controller.inconsistencias) {
    final estado = (inc['estado'] ?? '').toString().toUpperCase();
    if (estado == 'CERRADA') continue;
    final id = (inc['id_oficial'] ?? '').toString().trim();
    if (id.isEmpty) continue;
    score[id] = (score[id] ?? 0) + 1;
  }

  return score;
}

InputDecoration _inputDecoration({
  required String label,
  required Color color,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Colors.white70,
      fontFamily: 'Rajdhani',
    ),
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.28),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: color.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: color),
    ),
  );
}
