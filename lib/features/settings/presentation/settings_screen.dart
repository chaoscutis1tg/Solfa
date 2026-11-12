import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/providers/app_providers.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// UI-11: Cài đặt ứng dụng (UC-15 & BR-14)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cảnh báo xóa dữ liệu học tập'),
        content: const Text(
          'Hành động này sẽ xóa toàn bộ lịch sử phiên học, điểm số, thống kê độ chính xác, chuỗi ngày học và danh sách câu cần ôn tập trên thiết bị này. Dữ liệu đã xóa không thể khôi phục (BR-14). Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_clear_data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wrong,
              minimumSize: const Size(120, 42),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa dữ liệu'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.clearLearningHistory();
      ref.invalidate(overallProgressProvider);
      ref.invalidate(pendingReviewItemsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa toàn bộ lịch sử học tập cục bộ.'),
          ),
        );
      }
    }
  }

  Future<void> _showPrivacyAndLegalDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Quyền riêng tư & Pháp lý',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Bảo vệ dữ liệu cá nhân (Offline-First)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                '• Solfa hoạt động 100% ngoại tuyến (Offline-first) cho toàn bộ tính năng học tập và máy đếm nhịp.\n'
                '• Ứng dụng KHÔNG yêu cầu đăng ký tài khoản, KHÔNG thu thập họ tên, email, vị trí, danh bạ hay microphone.\n'
                '• Lịch sử học tập và cài đặt chỉ lưu cục bộ trên thiết bị của bạn (SQLite) và có thể xóa vĩnh viễn bất kỳ lúc nào tại mục "Xóa dữ liệu lịch sử học tập" (tuân thủ Nghị định 13/2023/NĐ-CP & Google Play Data Safety).',
                style: TextStyle(fontSize: 12.5, height: 1.42),
              ),
              SizedBox(height: 12),
              Text(
                '2. Bản quyền âm thanh & Nội dung học thuật',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                '• Toàn bộ mẫu âm thanh nốt nhạc Piano, quãng, vòng hòa âm và tiếng máy đếm nhịp cơ học (44.1kHz PCM WAV) được tổng hợp độc quyền bằng thuật toán xử lý tín hiệu số (DSP) của Solfa.\n'
                '• Nội dung nhạc lý thuộc phạm vi kiến thức âm nhạc phổ quát, không sử dụng bản ghi âm hoặc tác phẩm có bản quyền của bên thứ ba.',
                style: TextStyle(fontSize: 12.5, height: 1.42),
              ),
              SizedBox(height: 12),
              Text(
                '3. Chính sách Quảng cáo tự nguyện',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              SizedBox(height: 4),
              Text(
                '• Solfa cam kết không hiển thị quảng cáo tự động gây gián đoạn bài học.\n'
                '• Quyền kết nối Internet chỉ được sử dụng khi bạn chủ động bấm xem video tại mục "Hỗ trợ nhà phát triển".',
                style: TextStyle(fontSize: 12.5, height: 1.42),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(110, 40),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final audioService = ref.watch(audioServiceProvider);
    final selectedDuration = ref.watch(selectedPracticeDurationProvider);
    final adState = ref.watch(rewardedAdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Cài đặt hệ thống'),
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // 0. Brand Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    const SolfaLogo(size: 54, showShadow: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Solfa Studio v1.1',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.correct.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  '100% Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.correct,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Luyện cảm âm, tính điểm nốt nhạc & Máy đếm nhịp cơ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Giao diện nền Sáng / Tối
            const _SectionHeader(
              icon: Icons.palette_outlined,
              title: 'Giao diện & Nền hiển thị',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn chế độ hình nền âm nhạc (Sáng / Tối)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      key: const Key('segmented_theme_mode'),
                      children: [
                        _ThemeModeCardButton(
                          label: 'Nền Sáng',
                          icon: Icons.wb_sunny_rounded,
                          isSelected: settings.themeMode == ThemeMode.light,
                          isDark: isDark,
                          onTap: () => notifier.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeModeCardButton(
                          label: 'Nền Tối',
                          icon: Icons.nightlight_round,
                          isSelected: settings.themeMode == ThemeMode.dark,
                          isDark: isDark,
                          onTap: () => notifier.setThemeMode(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _ThemeModeCardButton(
                          label: 'Tự động',
                          icon: Icons.brightness_auto_rounded,
                          isSelected: settings.themeMode == ThemeMode.system,
                          isDark: isDark,
                          onTap: () => notifier.setThemeMode(ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Cấu hình Phòng luyện tập
            const _SectionHeader(
              icon: Icons.headset_rounded,
              title: 'Cấu hình Phòng luyện tập',
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thời gian luyện tập mặc định',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Áp dụng khi bắt đầu phiên luyện và tính điểm nốt đúng/sai',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _DurationChoiceButton(
                              label: '60 giây',
                              isSelected: selectedDuration == 60,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 60,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: '15 phút',
                              isSelected: selectedDuration == 900,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 900,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: '1 tiếng',
                              isSelected: selectedDuration == 3600,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 3600,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: 'Tự do',
                              isSelected: selectedDuration == 0,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('switch_unlock_all_levels'),
                    title: const Text(
                      'Mở khóa sẵn mọi cấp độ',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Cho phép vào ngay cấp Trung bình & Nâng cao',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings.unlockAllLevels,
                    onChanged: (v) => notifier.setUnlockAllLevels(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('switch_auto_play'),
                    title: const Text(
                      'Tự động phát âm thanh câu hỏi',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Tự phát nốt nhạc ngay khi chuyển sang câu hỏi mới',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings.autoPlayQuestionAudio,
                    onChanged: (v) => notifier.setAutoPlayAudio(v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Âm thanh & Máy đếm nhịp
            const _SectionHeader(
              icon: Icons.volume_up_rounded,
              title: 'Âm thanh & Máy đếm nhịp cơ',
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Âm lượng bài học & Phản hồi',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${(settings.lessonVolume * 100).round()}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: settings.lessonVolume,
                          min: 0.1,
                          max: 1.0,
                          onChanged: (v) => notifier.setLessonVolume(v),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () {
                                  audioService.playFeedbackSfx(isCorrect: true);
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 17,
                                  color: AppColors.correct,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Thử âm Đúng'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () {
                                  audioService.playReferenceC4();
                                },
                                icon: const Icon(
                                  Icons.piano_rounded,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Thử nốt Đô (C4)'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Âm báo phản hồi Đúng / Sai',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Phát chuông khi trả lời đúng và âm trầm khi sai',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings.feedbackSoundEnabled,
                    onChanged: (v) => notifier.setFeedbackSound(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Rung phản hồi nhẹ (Haptic)',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (v) => notifier.setHapticFeedback(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text(
                      'Giữ màn hình luôn sáng khi bật Metronome',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Ngăn điện thoại tự tắt màn hình khi đang giữ nhịp',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: settings.keepScreenAwakeOnMetronome,
                    onChanged: (v) => notifier.setKeepScreenAwake(v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Hỗ trợ, Quản lý dữ liệu & Pháp lý
            const _SectionHeader(
              icon: Icons.favorite_rounded,
              title: 'Hỗ trợ Nhà phát triển & Pháp lý',
            ),
            const SizedBox(height: 8),

            // Highlighted Standalone Red-Heart Developer Support Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF280D20).withOpacity(0.92),
                          const Color(0xFF140B29).withOpacity(0.92),
                        ]
                      : [
                          const Color(0xFFFFF0F3),
                          const Color(0xFFFFF8FA),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kHeartRedColor.withOpacity(isDark ? 0.55 : 0.42),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kHeartRedColor.withOpacity(isDark ? 0.18 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  key: const Key('tile_support_developer'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: const PulsingRedHeart(
                    size: 22,
                    showGlowBadge: true,
                  ),
                  title: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hỗ trợ nhà phát triển',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kHeartRedColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: kHeartRedColor.withOpacity(0.45),
                          ),
                        ),
                        child: Text(
                          adState.supportedCount > 0
                              ? '❤️ ${adState.supportedCount} lần • +${adState.prestigePoints}đ'
                              : '❤️ Ủng hộ 15s',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kHeartRedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      adState.supportedCount > 0
                          ? 'Danh hiệu: ${adState.supporterBadgeTitle} • Bấm để trao thêm ❤️'
                          : 'Xem video ngắn 15s tự nguyện để nhận Huy hiệu Tri Ân & Điểm Uy Tín',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.32,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: kHeartRedColor,
                  ),
                  onTap: () => context.push('/support-developer'),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('tile_privacy_legal'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.correct.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.correct,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Chính sách Quyền riêng tư & Pháp lý',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Bảo vệ dữ liệu cá nhân, bản quyền âm thanh & điều khoản',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showPrivacyAndLegalDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('tile_open_source_licenses'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Giấy phép mã nguồn mở',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Danh mục thư viện phần mềm nguồn mở (MIT / BSD / Apache)',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Solfa Studio',
                      applicationVersion: '1.1.0 (Offline-First)',
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SolfaLogo(size: 56),
                      ),
                      applicationLegalese:
                          '© 2026 Solfa Studio. Bản quyền âm thanh DSP 44.1kHz và nội dung nhạc lý thuộc về Solfa.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('tile_clear_history'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.wrong.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.wrong,
                        size: 21,
                      ),
                    ),
                    title: const Text(
                      'Xóa dữ liệu lịch sử học tập',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.wrong,
                      ),
                    ),
                    subtitle: const Text(
                      'Đặt lại toàn bộ điểm số, thống kê và câu ôn tập',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () => _confirmClearData(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ThemeModeCardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeModeCardButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? Colors.white.withOpacity(0.06)
                : AppColors.primary.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.primary.withOpacity(0.18),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationChoiceButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _DurationChoiceButton({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary
            : (isDark
                ? Colors.white.withOpacity(0.06)
                : AppColors.primary.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.secondary
                    : AppColors.primary.withOpacity(0.18),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
