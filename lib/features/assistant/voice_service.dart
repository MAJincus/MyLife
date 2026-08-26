import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Reconnaissance vocale (dictée) + synthèse vocale (lecture des réponses),
/// en français, via les moteurs du téléphone.
class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;

  bool get isListening => _stt.isListening;

  Future<bool> initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _sttReady;
  }

  /// Démarre l'écoute. [onPartial] reçoit la transcription en cours,
  /// [onFinal] la transcription finale quand l'utilisateur s'arrête.
  Future<bool> listen({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
  }) async {
    if (!await initStt()) return false;
    await _stt.listen(
      onResult: (r) {
        if (r.finalResult) {
          onFinal(r.recognizedWords);
        } else {
          onPartial(r.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: 'fr_FR',
      ),
    );
    return true;
  }

  Future<void> stopListening() => _stt.stop();

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.5);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() => _tts.stop();

  void dispose() {
    _stt.cancel();
    _tts.stop();
  }
}
