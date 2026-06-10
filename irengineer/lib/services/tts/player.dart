import 'package:just_audio/just_audio.dart';

/// Plays synthesized WAV files via just_audio.
class TtsPlayer {
  TtsPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  Future<void> play(String path) async {
    await _player.setFilePath(path);
    await _player.play();
    await _player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
