import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnRtcIceCandidate = void Function(RTCIceCandidate candidate);
typedef OnRtcConnectionState = void Function(RTCPeerConnectionState state);

class RadioRtcEngine {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final OnRtcIceCandidate? onLocalIceCandidate;
  final OnRtcConnectionState? onConnectionState;

  RadioRtcEngine({
    this.onLocalIceCandidate,
    this.onConnectionState,
  });

  bool get isReady => _peerConnection != null;

  Future<void> initialize() async {
    if (_peerConnection != null) return;

    final mediaConstraints = <String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    final configuration = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[
        <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(configuration);

    for (final track in _localStream!.getAudioTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      onLocalIceCandidate?.call(candidate);
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionState?.call(state);
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        onConnectionState
            ?.call(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
      }
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onConnectionState
            ?.call(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      }
    };

    _peerConnection = pc;
  }

  Future<Map<String, dynamic>> createOffer() async {
    await initialize();
    final pc = _peerConnection!;
    final offer = await pc.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(offer);
    return _serializeSessionDescription(offer);
  }

  Future<void> applyRemoteOffer(Map<String, dynamic> offerData) async {
    await initialize();
    final pc = _peerConnection!;
    final desc = _deserializeSessionDescription(offerData);
    await pc.setRemoteDescription(desc);
  }

  Future<Map<String, dynamic>> createAnswer() async {
    await initialize();
    final pc = _peerConnection!;
    final answer = await pc.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await pc.setLocalDescription(answer);
    return _serializeSessionDescription(answer);
  }

  Future<void> applyRemoteAnswer(Map<String, dynamic> answerData) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final desc = _deserializeSessionDescription(answerData);
    await pc.setRemoteDescription(desc);
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> candidateData) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final candidate = RTCIceCandidate(
      (candidateData['candidate'] ?? '').toString(),
      (candidateData['sdpMid'] ?? '').toString(),
      (candidateData['sdpMLineIndex'] as num?)?.toInt() ?? 0,
    );
    await pc.addCandidate(candidate);
  }

  Future<void> close() async {
    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
      try {
        await stream.dispose();
      } catch (_) {}
    }
    _localStream = null;
  }

  Map<String, dynamic> _serializeSessionDescription(
    RTCSessionDescription desc,
  ) {
    return <String, dynamic>{
      'sdp': desc.sdp ?? '',
      'type': desc.type ?? '',
    };
  }

  RTCSessionDescription _deserializeSessionDescription(
    Map<String, dynamic> data,
  ) {
    return RTCSessionDescription(
      (data['sdp'] ?? '').toString(),
      (data['type'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> serializeIceCandidate(RTCIceCandidate c) {
    return <String, dynamic>{
      'candidate': c.candidate,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    };
  }
}
