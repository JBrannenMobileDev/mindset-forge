import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/encouragement_message.dart';
import '../../providers/auth_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: AppTextStyles.headlineMedium),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load notifications.')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final messages = profile.encouragementMessages;
          if (messages.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No messages yet',
              subtitle: 'Encouragement from your accountability partner will appear here.',
            );
          }

          final sorted = [...messages]
            ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.lg,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final msg = sorted[i];
              return _MessageCard(
                message: msg,
                onRead: () async {
                  if (!msg.read) {
                    final uid = ref.read(authStateProvider).valueOrNull?.uid;
                    if (uid == null) return;
                    final updated = messages.map((m) {
                      if (m.id == msg.id) return m.copyWith(read: true);
                      return m;
                    }).toList();
                    await ref.read(firestoreServiceProvider).updateUserField(uid, {
                      'encouragementMessages': updated.map((m) => m.toJson()).toList(),
                    });
                  }
                },
              ).animate().fadeIn(delay: Duration(milliseconds: i * 60), duration: 400.ms);
            },
          );

        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final EncouragementMessage message;
  final VoidCallback onRead;

  const _MessageCard({required this.message, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.read;

    return AppCard(
      onTap: onRead,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: isUnread ? AppColors.primaryContainer : AppColors.surfaceElevated,
      borderColor: isUnread ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
        child: Text(
                    message.fromName.isNotEmpty
                        ? message.fromName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                  ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                            children: [
                              Text(message.fromName, style: AppTextStyles.labelLarge),
                              if (isUnread) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                            message.message,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatDate(message.sentAt),
                            style: AppTextStyles.labelSmall,
                          ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}
