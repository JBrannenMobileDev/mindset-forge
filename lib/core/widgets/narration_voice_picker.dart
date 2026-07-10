import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../constants/future_self_voices.dart';

/// Four-option narrator voice picker with bundled preview clips, grouped by
/// lighter vs deeper tone.
class NarrationVoicePicker extends StatefulWidget {
  final String selectedVoiceId;
  final ValueChanged<String> onSelected;

  const NarrationVoicePicker({
    super.key,
    required this.selectedVoiceId,
    required this.onSelected,
  });

  @override
  State<NarrationVoicePicker> createState() => _NarrationVoicePickerState();
}

class _NarrationVoicePickerState extends State<NarrationVoicePicker> {
  final AudioPlayer _preview = AudioPlayer();
  String? _playingVoiceId;

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String voiceId, String assetPath) async {
    if (_playingVoiceId == voiceId) {
      await _preview.stop();
      if (mounted) setState(() => _playingVoiceId = null);
      return;
    }

    try {
      await _preview.stop();
      await _preview.setAsset(assetPath);
      if (!mounted) return;
      setState(() => _playingVoiceId = voiceId);
      await _preview.play();
      _preview.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      ).then((_) {
        if (mounted) setState(() => _playingVoiceId = null);
      });
    } catch (_) {
      if (mounted) setState(() => _playingVoiceId = null);
    }
  }

  String _labelFor(FutureSelfVoiceOption option) => switch (option.labelKey) {
        'light' => AppStrings.futureSelfNarrationVoiceLighter,
        'smooth' => AppStrings.futureSelfNarrationVoiceSmooth,
        'deep' => AppStrings.futureSelfNarrationVoiceDeeper,
        'grounded' => AppStrings.futureSelfNarrationVoiceGrounded,
        _ => option.labelKey,
      };

  String _groupTitle(String groupKey) => switch (groupKey) {
        FutureSelfVoices.groupLighter =>
          AppStrings.futureSelfNarrationVoiceLighterGroup,
        FutureSelfVoices.groupDeeper =>
          AppStrings.futureSelfNarrationVoiceDeeperGroup,
        _ => groupKey,
      };

  Widget _buildGroup(String groupKey) {
    final groupOptions = FutureSelfVoices.optionsForGroup(groupKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _groupTitle(groupKey),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...groupOptions.map(
          (option) => _VoiceCard(
            label: _labelFor(option),
            selected: widget.selectedVoiceId == option.voiceId,
            playing: _playingVoiceId == option.voiceId,
            onTap: () => widget.onSelected(option.voiceId),
            onPreview: () =>
                _togglePreview(option.voiceId, option.previewAsset),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.futureSelfNarrationVoiceTitle,
          style: AppTextStyles.labelLarge
              .copyWith(color: AppColors.futureSelfAccent),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.futureSelfNarrationVoiceSubtitle,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildGroup(FutureSelfVoices.groupLighter),
        const SizedBox(height: AppSpacing.lg),
        _buildGroup(FutureSelfVoices.groupDeeper),
      ],
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  const _VoiceCard({
    required this.label,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.futureSelfSurface,
            border: Border.all(
              color: selected
                  ? AppColors.futureSelfAccent
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: selected
                        ? AppColors.futureSelfAccent
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.futureSelfNarrationVoicePreview,
                onPressed: onPreview,
                icon: Icon(
                  playing
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                  color: AppColors.futureSelfAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
