import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// A selectable binaural-beat frequency band.
class BinauralBand {
  final int hz;
  final String name;
  final String description;

  const BinauralBand(this.hz, this.name, this.description);
}

/// Synthesizes real binaural beats on-device (no audio assets) and plays them
/// on a loop via [just_audio]. A binaural beat is the perceptual tone created
/// when each ear hears a slightly different frequency; the brain "hears" the
/// difference. Here the left ear gets [_baseHz] and the right ear gets
/// [_baseHz] + the selected beat frequency.
///
/// Headphones are required for the effect — each channel must reach a separate
/// ear. A 1-second stereo PCM buffer is generated and looped; because the base
/// and beat frequencies are integers, exactly whole cycles fit in one second so
/// the loop is seamless (no click at the boundary).
class BinauralBeatController {
  final AudioPlayer _player = AudioPlayer();

  static const int _sampleRate = 44100;
  static const int _baseHz = 200;
  static const double _amplitude = 0.6;

  int _hz;
  double _volume;
  bool _isPlaying = false;
  bool _disposed = false;

  BinauralBeatController({int hz = 7, double volume = 0.3})
      : _hz = hz,
        _volume = volume;

  /// The bands offered in the UI (theta/alpha are the receptive defaults).
  static const List<BinauralBand> bands = [
    BinauralBand(4, 'Delta 4Hz', 'Deep rest'),
    BinauralBand(7, 'Theta 7Hz', 'Deep meditation'),
    BinauralBand(10, 'Alpha 10Hz', 'Relaxed focus'),
    BinauralBand(15, 'Beta 15Hz', 'Alert'),
    BinauralBand(40, 'Gamma 40Hz', 'Peak focus'),
  ];

  int get hz => _hz;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;

  Future<void> _load() async {
    final wav = _generateWav(_baseHz, _baseHz + _hz);
    await _player.setAudioSource(_WavStreamSource(wav));
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(_volume);
  }

  Future<void> play() async {
    if (_disposed) return;
    if (_player.audioSource == null) await _load();
    await _player.setVolume(_volume);
    await _player.play();
    _isPlaying = true;
  }

  Future<void> pause() async {
    if (_disposed) return;
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> setFrequency(int hz) async {
    if (_disposed || hz == _hz) return;
    _hz = hz;
    final wasPlaying = _isPlaying;
    await _load();
    if (wasPlaying) await _player.play();
  }

  Future<void> setVolume(double value) async {
    if (_disposed) return;
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _player.dispose();
  }

  /// Builds a 1-second 16-bit stereo PCM WAV with [leftHz] in the left channel
  /// and [rightHz] in the right.
  Uint8List _generateWav(int leftHz, int rightHz) {
    const seconds = 1;
    const channels = 2;
    const bytesPerSample = 2;
    const numSamples = _sampleRate * seconds;
    const dataSize = numSamples * channels * bytesPerSample;
    const byteRate = _sampleRate * channels * bytesPerSample;

    final data = ByteData(dataSize);
    int offset = 0;
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      final left =
          (math.sin(2 * math.pi * leftHz * t) * _amplitude * 32767).round();
      final right =
          (math.sin(2 * math.pi * rightHz * t) * _amplitude * 32767).round();
      data.setInt16(offset, left, Endian.little);
      offset += 2;
      data.setInt16(offset, right, Endian.little);
      offset += 2;
    }

    final header = BytesBuilder();
    void writeStr(String s) => header.add(s.codeUnits);
    void writeU32(int v) => header
        .add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void writeU16(int v) => header.add([v & 0xff, (v >> 8) & 0xff]);

    writeStr('RIFF');
    writeU32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(channels);
    writeU32(_sampleRate);
    writeU32(byteRate);
    writeU16(channels * bytesPerSample);
    writeU16(16); // bits per sample
    writeStr('data');
    writeU32(dataSize);
    header.add(data.buffer.asUint8List());

    return header.toBytes();
  }
}

/// Serves the generated WAV bytes to [just_audio] as an in-memory source.
class _WavStreamSource extends StreamAudioSource {
  final Uint8List _bytes;

  _WavStreamSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
