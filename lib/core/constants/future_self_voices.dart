/// Curated TTS voices for Future Self narration previews and synthesis.
class FutureSelfVoices {
  FutureSelfVoices._();

  static const String aoede = 'en-US-Chirp3-HD-Aoede';
  static const String despina = 'en-US-Chirp3-HD-Despina';
  static const String charon = 'en-US-Chirp3-HD-Charon';
  static const String enceladus = 'en-US-Chirp3-HD-Enceladus';
  static const String defaultVoice = charon;

  static const String groupLighter = 'lighter';
  static const String groupDeeper = 'deeper';

  /// Bundled preview clips (same pace as live narration).
  static const String previewAssetAoede =
      'assets/audio/future_self_voice_aoede.mp3';
  static const String previewAssetDespina =
      'assets/audio/future_self_voice_despina.mp3';
  static const String previewAssetCharon =
      'assets/audio/future_self_voice_charon.mp3';
  static const String previewAssetEnceladus =
      'assets/audio/future_self_voice_enceladus.mp3';

  static const List<FutureSelfVoiceOption> options = [
    FutureSelfVoiceOption(
      voiceId: aoede,
      labelKey: 'light',
      groupKey: groupLighter,
      previewAsset: previewAssetAoede,
    ),
    FutureSelfVoiceOption(
      voiceId: despina,
      labelKey: 'smooth',
      groupKey: groupLighter,
      previewAsset: previewAssetDespina,
    ),
    FutureSelfVoiceOption(
      voiceId: charon,
      labelKey: 'deep',
      groupKey: groupDeeper,
      previewAsset: previewAssetCharon,
    ),
    FutureSelfVoiceOption(
      voiceId: enceladus,
      labelKey: 'grounded',
      groupKey: groupDeeper,
      previewAsset: previewAssetEnceladus,
    ),
  ];

  static List<FutureSelfVoiceOption> optionsForGroup(String groupKey) =>
      options.where((o) => o.groupKey == groupKey).toList();

  static String resolve(String preferred) =>
      preferred.isNotEmpty ? preferred : defaultVoice;

  static String previewAssetFor(String voiceId) {
    for (final o in options) {
      if (o.voiceId == voiceId) return o.previewAsset;
    }
    return previewAssetCharon;
  }
}

class FutureSelfVoiceOption {
  final String voiceId;
  final String labelKey;
  final String groupKey;
  final String previewAsset;

  const FutureSelfVoiceOption({
    required this.voiceId,
    required this.labelKey,
    required this.groupKey,
    required this.previewAsset,
  });
}
