import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../topics/presentation/topics_screen.dart';

/// UI-02: Trang chủ (UC-01 & UC-02)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startQuickPractice(
    BuildContext context,
    WidgetRef ref, {
    String? topicId,
    String? levelId,
  }) async {
    final notifier = ref.read(practiceSessionProvider.notifier);
    final isTest = ref.read(audioServiceProvider).isTestMode;
    final dur = ref.read(selectedPracticeDurationProvider);

    final ok = await notifier.startSession(
      mode: topicId != null ? 'topic' : 'quick',
      topicId: topicId,
      levelId: levelId,
      targetCount: 10,
      timeLimitSeconds: isTest ? null : (dur == 0 ? null : dur),
      isUnlimitedMode: isTest ? false : (dur == 0),
    );
    if (ok && context.mounted) {
      context.push('/quiz');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(overallProgressProvider);
    final topicsAsync = ref.watch(topicsListProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(overallProgressProvider);
        ref.invalidate(topicsListProvider);
        ref.invalidate(pendingReviewItemsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // 1. Hero Quick Practice Banner (UC-02)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0D6EFD),
                  Color(0xFF084EB2),
                  Color(0xFF063782),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.26),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFFFD166),
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tính điểm nốt Đúng / Sai • Offline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SolfaLogo(size: 44, showShadow: false),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Phòng luyện cảm âm nhanh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.5,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Chọn thời gian luyện tập (60 giây, 15 phút, 1 tiếng hoặc Không giới hạn) và xem điểm số nốt đúng/sai trực tiếp.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                // Quick Duration Mode Pills
                Row(
                  children: [
                    _HeroDurationChip(
                      label: '60 giây',
                      isSelected: selectedDuration == 60,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 60,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: '15 phút',
                      isSelected: selectedDuration == 900,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 900,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: '1 tiếng',
                      isSelected: selectedDuration == 3600,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 3600,
                    ),
                    const SizedBox(width: 6),
                    _HeroDurationChip(
                      label: 'Tự do',
                      isSelected: selectedDuration == 0,
                      onTap: () => ref
                          .read(selectedPracticeDurationProvider.notifier)
                          .state = 0,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('btn_quick_practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => _startQuickPractice(context, ref),
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 22,
                      color: AppColors.accentAmber,
                    ),
                    label: Text(
                      'Luyện tập ngay (${TopicsScreen.durationLabel(selectedDuration)})',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Quick Utility Bento Row (Metronome + Review)
          progressAsync.maybeWhen(
            data: (stats) => _buildUtilityRow(context, stats),
            orElse: () => _buildUtilityRow(context, null),
          ),
          const SizedBox(height: 16),

          // 3. Progress / First-Time Guidance Section (UC-01)
          progressAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải thống kê: $e'),
              ),
            ),
            data: (stats) => _buildProgressSection(context, ref, stats),
          ),

          const SizedBox(height: 18),

          // 4. Core Topics Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chủ đề cốt lõi',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => context.go('/topics'),
                child: const Text(
                  'Vào phòng luyện',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          topicsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (topics) {
              final stats = progressAsync.valueOrNull;
              final enabledTopics = topics.where((t) => t.isEnabled).toList();
              return Column(
                children: List.generate(enabledTopics.length, (i) {
                  final topic = enabledTopics[i];
                  final topicAcc = stats?.topicStats
                      .where((s) => s.topicId == topic.id)
                      .firstOrNull;
                  final accent = AppColors.topicAccent(topic.code);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/topics/${topic.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      _iconForTopic(topic.code),
                                      color: accent,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                topic.name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (topicAcc != null &&
                                                topicAcc.totalAnswered > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      accent.withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                                child: Text(
                                                  '${topicAcc.accuracyPercent.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: accent,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          topic.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: accent,
                                  ),
                                ],
                              ),
                              if (topicAcc != null &&
                                  topicAcc.totalAnswered > 0) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: (topicAcc.accuracyPercent / 100.0)
                                        .clamp(0.0, 1.0),
                                    minHeight: 5,
                                    backgroundColor: accent.withOpacity(0.14),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(accent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/support-developer'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accentCoral.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.smart_display_rounded,
                        color: AppColors.accentCoral,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ủng hộ nhà phát triển (Xem video 15s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tự nguyện xem video quảng cáo ngắn khi có mạng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accentCoral,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityRow(BuildContext context, OverallProgressStats? stats) {
    final pendingCount = stats?.pendingReviewCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/metronome'),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.av_timer_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metronome',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nhịp cơ chuẩn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5),
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
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/review'),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (pendingCount > 0
                                ? AppColors.wrong
                                : AppColors.correct)
                            .withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        pendingCount > 0
                            ? Icons.auto_fix_high_rounded
                            : Icons.verified_rounded,
                        color: pendingCount > 0
                            ? AppColors.wrong
                            : AppColors.correct,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ôn câu sai',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingCount > 0
                                ? '$pendingCount câu cần ôn'
                                : '0 câu tồn đọng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: pendingCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: pendingCount > 0 ? AppColors.wrong : null,
                            ),
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
      ],
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    WidgetRef ref,
    OverallProgressStats stats,
  ) {
    if (!stats.hasAnyHistory) {
      // First-time user flow (UC-01 Alternative Flow)
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu hành trình đầu tiên',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gợi ý khởi động nhanh cho người mới:',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Bài "Nhận biết nốt (Cơ bản)" có nút nghe nốt Đô chuẩn (C4) và bàn phím đàn trực quan giúp bạn làm quen dễ dàng.',
                style: TextStyle(fontSize: 13, height: 1.38),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('btn_first_time_notes'),
                onPressed: () => _startQuickPractice(
                  context,
                  ref,
                  topicId: 'topic_notes',
                  levelId: 'lvl_notes_basic',
                ),
                icon: const Icon(Icons.music_note_rounded, size: 20),
                label: const Text('Học ngay: Nhận biết nốt (Cơ bản)'),
              ),
            ],
          ),
        ),
      );
    }

    final latestSession =
        stats.recentSessions.isNotEmpty ? stats.recentSessions.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.query_stats_rounded, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tiến trình của bạn',
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatMiniCard(
                label: 'Chính xác',
                value: '${stats.overallAccuracyPercent.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.correct,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatMiniCard(
                label: 'Nốt đã nghe',
                value: '${stats.totalAnswered}',
                icon: Icons.quiz_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatMiniCard(
                label: 'Chuỗi ngày',
                value: '${stats.currentStreakDays} ngày',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.accentAmber,
              ),
            ),
          ],
        ),
        if (latestSession != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phiên gần nhất: ${latestSession.topicName ?? 'Luyện tập'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đúng ${latestSession.correctCount}/${latestSession.totalQuestions} nốt • Điểm: ${latestSession.correctCount * 10} • ${NoteFormatter.formatDurationSeconds(latestSession.durationSeconds)}',
                              style: const TextStyle(fontSize: 12.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: () => _startQuickPractice(
                      context,
                      ref,
                      topicId: latestSession.topicId,
                      levelId: latestSession.levelId,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Tiếp tục chủ đề này'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _iconForTopic(String code) {
    switch (code) {
      case 'note_recognition':
      case 'notes':
        return Icons.music_note_rounded;
      case 'interval_recognition':
      case 'intervals':
        return Icons.swap_vert_circle_outlined;
      case 'key_recognition':
      case 'chords':
        return Icons.library_music_rounded;
      default:
        return Icons.queue_music_rounded;
    }
  }
}

class _HeroDurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HeroDurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? const Color(0xFFFFD166)
            : Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF0A214A) : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
