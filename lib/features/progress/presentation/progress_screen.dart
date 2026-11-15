import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/note_formatter.dart';

/// UI-09: Tiến trình & Lịch sử (UC-13)
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(overallProgressProvider);

    return progressAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải tiến trình: $e')),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(overallProgressProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // Top Review Wrong Answers Action Card (Spacious vertical layout - no edge crowding!)
              FadeSlideIn(
                index: 0,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: stats.pendingReviewCount > 0
                                    ? AppColors.wrongBgLight
                                    : AppColors.correctBgLight,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                stats.pendingReviewCount > 0
                                    ? Icons.auto_fix_high_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: stats.pendingReviewCount > 0
                                    ? AppColors.wrong
                                    : AppColors.correct,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stats.pendingReviewCount > 0
                                        ? 'Ôn tập câu sai (${stats.pendingReviewCount} câu)'
                                        : 'Ôn tập câu sai (0 câu cần ôn)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Luyện lại các câu sai cho đến khi thuộc bài',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          key: const Key('btn_open_review_screen'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          onPressed: () => context.push('/review'),
                          icon: const Icon(Icons.replay_rounded, size: 19),
                          label: const Text('Mở ôn tập câu sai'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (!stats.hasAnyHistory)
                FadeSlideIn(
                  index: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa có dữ liệu luyện tập',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Hoàn thành phiên luyện tập đầu tiên để xem biểu đồ độ chính xác và lịch sử học tập tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, height: 1.38),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Bắt đầu luyện tập ngay'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Summary KPI Grid
                const FadeSlideIn(
                  index: 1,
                  child: Text(
                    'Chỉ số tổng quan',
                    style:
                        TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 2,
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      _KpiTile(
                        label: 'Tổng câu đã làm',
                        value: '${stats.totalAnswered} câu',
                        sub: 'Đúng ${stats.totalCorrect} câu',
                        icon: Icons.quiz_outlined,
                        color: AppColors.primary,
                      ),
                      _KpiTile(
                        label: 'Độ chính xác',
                        value:
                            '${stats.overallAccuracyPercent.toStringAsFixed(1)}%',
                        sub: 'Toàn bộ phiên',
                        icon: Icons.verified_outlined,
                        color: AppColors.correct,
                      ),
                      _KpiTile(
                        label: 'Thời gian luyện',
                        value: NoteFormatter.formatDurationSeconds(
                          stats.totalDurationSeconds,
                        ),
                        sub: 'Thời gian thực tế',
                        icon: Icons.timer_outlined,
                        color: AppColors.accentCyan,
                      ),
                      _KpiTile(
                        label: 'Chuỗi ngày học',
                        value: '${stats.currentStreakDays} ngày',
                        sub: 'Duy trì đều đặn',
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.accentAmber,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                if (stats.noteMasteryStats.isNotEmpty) ...[
                  const FadeSlideIn(
                    index: 3,
                    child: Text(
                      'Bản đồ độ nhạy từng nốt (Note Heatmap)',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 3,
                    child: _NoteMasteryHeatmapCard(
                      noteStats: stats.noteMasteryStats,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const FadeSlideIn(
                  index: 3,
                  child: Text(
                    'Độ chính xác theo chủ đề',
                    style:
                        TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 4,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 180,
                            child: IgnorePointer(
                              child: BarChart(
                                BarChartData(
                                  barTouchData: BarTouchData(enabled: false),
                                  maxY: 100,
                                  minY: 0,
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: 25,
                                ),
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: 70,
                                      color: AppColors.correct.withOpacity(0.5),
                                      strokeWidth: 1.5,
                                      dashArray: [6, 4],
                                    ),
                                  ],
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 38,
                                      interval: 25,
                                      getTitlesWidget: (val, _) => Text(
                                        '${val.toInt()}%',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, _) {
                                        final idx = val.toInt();
                                        if (idx < 0 ||
                                            idx >= stats.topicStats.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final rawName = stats
                                            .topicStats[idx].topicName;
                                        final shortName = rawName ==
                                                'Nhận biết nốt'
                                            ? 'Nghe'
                                            : rawName == 'Đọc nốt nhạc'
                                                ? 'Đọc'
                                                : rawName == 'Nhận biết quãng'
                                                    ? 'Quãng'
                                                    : rawName == 'Nhận biết giọng'
                                                        ? 'Giọng'
                                                        : rawName ==
                                                                'Nhận biết hợp âm'
                                                            ? 'H.âm'
                                                            : rawName.contains(
                                                                    'giai điệu')
                                                                ? 'G.điệu'
                                                                : rawName.contains(
                                                                        'nhịp')
                                                                    ? 'Nhịp'
                                                                    : rawName
                                                                        .replaceAll(
                                                                        'Nhận biết ',
                                                                        '',
                                                                      );
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            shortName,
                                            style: const TextStyle(
                                              fontSize: 9.8,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: [
                                  for (int i = 0;
                                      i < stats.topicStats.length;
                                      i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: stats.topicStats[i].hasEnoughData
                                              ? stats.topicStats[i]
                                                  .accuracyPercent
                                              : 0,
                                          width: 14,
                                          gradient:
                                              stats.topicStats[i].hasEnoughData
                                                  ? const LinearGradient(
                                                      colors: [
                                                        AppColors.primary,
                                                        AppColors.secondary,
                                                      ],
                                                      begin:
                                                          Alignment.bottomCenter,
                                                      end: Alignment.topCenter,
                                                    )
                                                  : null,
                                          color: stats
                                                  .topicStats[i].hasEnoughData
                                              ? null
                                              : Colors.grey.withOpacity(0.30),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 6),
                          ...stats.topicStats.map((tStat) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${tStat.topicName} (${tStat.totalAnswered} câu)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!tStat.hasEnoughData)
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Chưa đủ dữ liệu (< 5 câu)',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '${tStat.accuracyPercent.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: tStat.accuracyPercent >= 70
                                            ? AppColors.correct
                                            : AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const FadeSlideIn(
                  index: 5,
                  child: Text(
                    'Lịch sử phiên gần đây',
                    style:
                        TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(stats.recentSessions.length, (idx) {
                  final session = stats.recentSessions[idx];
                  final dateFormatted = DateFormat('dd/MM/yyyy HH:mm')
                      .format(session.startedAt);
                  final acc = session.accuracyPercent;
                  return FadeSlideIn(
                    index: 6 + idx,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: acc >= 70
                                  ? AppColors.correctBgLight
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${acc.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: acc >= 70
                                    ? AppColors.correct
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            session.mode == 'review'
                                ? 'Ôn tập câu sai (${session.topicName ?? 'Tổng hợp'})'
                                : '${session.topicName ?? 'Luyện tập'}${session.levelName != null ? ' • ${session.levelName}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            '$dateFormatted • Đúng ${session.correctCount}/${session.totalQuestions} (${NoteFormatter.formatDurationSeconds(session.durationSeconds)})',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _KpiTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteMasteryHeatmapCard extends ConsumerWidget {
  final List<NoteMasteryStat> noteStats;

  const _NoteMasteryHeatmapCard({
    required this.noteStats,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = ref.watch(audioServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final practiced = noteStats.where((n) => n.totalAnswered > 0).toList();

    NoteMasteryStat? bestNote;
    NoteMasteryStat? weakestNote;
    if (practiced.isNotEmpty) {
      final sortedDesc = [...practiced]..sort((a, b) {
          final cmp = b.accuracyPercent.compareTo(a.accuracyPercent);
          return cmp != 0 ? cmp : b.totalAnswered.compareTo(a.totalAnswered);
        });
      bestNote = sortedDesc.first;

      final sortedAsc = [...practiced]..sort((a, b) {
          final cmp = a.accuracyPercent.compareTo(b.accuracyPercent);
          return cmp != 0 ? cmp : b.totalAnswered.compareTo(a.totalAnswered);
        });
      if (sortedAsc.first.accuracyPercent < 95.0 || sortedAsc.length > 1) {
        weakestNote = sortedAsc.first;
      }
    }

    return Card(
      key: const Key('note_mastery_heatmap_card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bestNote != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          size: 16,
                          color: AppColors.correct,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Nhạy nhất: ${bestNote.solfegeLabel} (${bestNote.pitchClass}) • Đúng ${bestNote.accuracyPercent.toStringAsFixed(0)}% (${bestNote.correctCount}/${bestNote.totalAnswered})',
                            style: const TextStyle(
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (weakestNote != null &&
                        weakestNote.pitchClass != bestNote.pitchClass) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.tips_and_updates_outlined,
                            size: 16,
                            color: AppColors.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cần luyện thêm: ${weakestNote.solfegeLabel} (${weakestNote.pitchClass}) • Đúng ${weakestNote.accuracyPercent.toStringAsFixed(0)}% (${weakestNote.correctCount}/${weakestNote.totalAnswered})',
                              style: const TextStyle(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: noteStats.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.28,
              ),
              itemBuilder: (context, idx) {
                final item = noteStats[idx];
                final hasData = item.totalAnswered > 0;
                final acc = item.accuracyPercent;

                final Color badgeColor = !hasData
                    ? Colors.grey
                    : (acc >= 80
                        ? AppColors.correct
                        : (acc >= 50 ? AppColors.accentAmber : AppColors.wrong));

                return Material(
                  color: hasData
                      ? badgeColor.withOpacity(isDark ? 0.18 : 0.11)
                      : (isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.grey.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key('heatmap_note_${item.pitchClass}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      audioService.playPianoKey('${item.pitchClass}4');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasData
                              ? badgeColor.withOpacity(0.55)
                              : Colors.grey.withOpacity(0.22),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${item.solfegeLabel} (${item.pitchClass})',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: hasData ? badgeColor : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              hasData
                                  ? '${acc.toStringAsFixed(0)}% (${item.correctCount}/${item.totalAnswered})'
                                  : 'Chưa luyện',
                              style: TextStyle(
                                fontSize: 10.2,
                                fontWeight: FontWeight.w700,
                                color: hasData
                                    ? badgeColor
                                    : Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Chạm vào ô nốt bất kỳ để nghe lại âm chuẩn của nốt đó',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
