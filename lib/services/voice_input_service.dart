abstract class VoiceInputService {
  Future<String?> startListening();
}

class PrototypeVoiceInputService implements VoiceInputService {
  @override
  Future<String?> startListening() async => null;
}
