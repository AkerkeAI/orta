enum OrtaRealtimeVoiceState {
  disconnected,
  connecting,
  listening,
  thinking,
  speaking,
  error,
}

abstract class OrtaRealtimeVoiceService {
  OrtaRealtimeVoiceState get state;
  Future<void> connect();
  Future<void> disconnect();
}

class PrototypeRealtimeVoiceService implements OrtaRealtimeVoiceService {
  @override
  OrtaRealtimeVoiceState state = OrtaRealtimeVoiceState.disconnected;
  @override
  Future<void> connect() async {
    state = OrtaRealtimeVoiceState.error;
  }

  @override
  Future<void> disconnect() async {
    state = OrtaRealtimeVoiceState.disconnected;
  }
}
