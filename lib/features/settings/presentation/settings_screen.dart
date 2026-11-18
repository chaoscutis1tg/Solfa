import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/pulsing_red_heart.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_gem_icon.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/providers/app_providers.dart';
import '../../metronome/application/metronome_controller.dart';
import '../../practice/application/practice_session_controller.dart';
import '../../support_developer/application/rewarded_ad_controller.dart';

/// Màn hình Cài đặt hệ thống
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showCountrySelectorModal(
    BuildContext context,
    AppSettingsState settings,
    AppSettingsNotifier notifier,
  ) async {
    final isEn = settings.isEnglish;
    final countries = AppLocale.selectableCountries;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151926) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Select Country / Region (174+ Global Regions)'
                          : 'Chọn Quốc gia / Khu vực (174+ Quốc gia)',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'Offline detection via device locale (no GPS/tracking). Compliant with EU Regulation 2018/302.'
                    : 'Nhận diện cục bộ qua vùng thiết bị (không dùng GPS). Tuân thủ Quy định (EU) 2018/302.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      key: const Key('tile_country_auto'),
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Text('🧭', style: TextStyle(fontSize: 20)),
                      title: Text(
                        isEn
                            ? 'Auto-detect from Device Locale'
                            : 'Tự động nhận diện theo thiết bị',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        isEn
                            ? 'Default recommended setting'
                            : 'Khuyên dùng (mặc định)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: settings.countryCodeOverride.isEmpty
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.correct,
                            )
                          : null,
                      onTap: () {
                        notifier.setCountryCodeOverride('');
                        Navigator.of(ctx).pop();
                      },
                    ),
                    const Divider(height: 8),
                    for (final c in countries)
                      ListTile(
                        key: Key('tile_country_${c.countryCode}'),
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Text(
                          c.flagEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(
                          '${c.displayName(isEn)} (${c.countryCode})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${c.regulatoryRegion} • ${c.defaultLanguageCode == 'vi' ? 'Tiếng Việt' : 'English'}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: settings.countryCodeOverride == c.countryCode
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.correct,
                              )
                            : null,
                        onTap: () {
                          notifier.setCountryCodeOverride(c.countryCode);
                          Navigator.of(ctx).pop();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final isEn = ref.read(appSettingsProvider).isEnglish;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.wrong.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.wrong,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEn
                        ? 'Clear Learning History Warning'
                        : 'Cảnh báo xóa dữ liệu học tập',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isEn
                  ? 'This action will permanently delete all local practice sessions, scores, accuracy stats, daily streaks, and pending review questions on this device. Deleted data cannot be recovered. Are you sure you want to continue?'
                  : 'Hành động này sẽ xóa toàn bộ lịch sử phiên học, điểm số, thống kê độ chính xác, chuỗi ngày học và danh sách câu cần ôn tập trên thiết bị này. Dữ liệu đã xóa không thể khôi phục. Bạn có chắc chắn muốn tiếp tục?',
              style: const TextStyle(fontSize: 13.2, height: 1.38),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        isEn ? 'Cancel' : 'Hủy',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      key: const Key('btn_confirm_clear_data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.wrong,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isEn ? 'Delete Data' : 'Xóa dữ liệu',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final db = ref.read(appDatabaseProvider);
      await db.clearLearningHistory();
      ref.invalidate(overallProgressProvider);
      ref.invalidate(pendingReviewItemsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEn
                  ? 'All local learning history has been cleared.'
                  : 'Đã xóa toàn bộ lịch sử học tập cục bộ.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showPrivacyAndLegalDialog(
    BuildContext context, {
    bool initialEnglish = false,
  }) async {
    bool showEn = initialEnglish;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showEn
                      ? 'Privacy & Legal Compliance'
                      : 'Quyền riêng tư & Pháp lý',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                key: const Key('btn_toggle_legal_language'),
                borderRadius: BorderRadius.circular(99),
                onTap: () => setDialogState(() => showEn = !showEn),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                    ),
                  ),
                  child: Text(
                    showEn ? '🇻🇳 VI' : '🇬🇧 EN',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: showEn
                  ? const [
                      Text(
                        '1. Personal Data Protection (100% Offline-First, GDPR & CCPA)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Solfa operates 100% offline for all music learning, ear training, Piano/Guitar studios, and metronome features.\n'
                        '• The app does NOT require user registration and does NOT collect names, emails, GPS location, contacts, or microphone data.\n'
                        '• All learning progress and settings are stored strictly locally on your device (SQLite) and can be permanently erased at any time via "Clear Learning History" (compliant with EU GDPR, US CCPA, VN Decree 13/2023/ND-CP & Google Play Data Safety).',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '2. EU Geo-blocking Regulation (EU) 2018/302 & Global Distribution (174+ Countries)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• In compliance with Regulation (EU) 2018/302 of the European Parliament and of the Council on addressing unjustified geo-blocking, Solfa provides equal, non-discriminatory access across all 27 EU/EEA Member States and 174+ countries worldwide.\n'
                        '• Solfa applies zero regional restrictions, zero nationality/residence discrimination, and automatically adapts interface language (Vietnamese / English) solely via local device locale settings.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '3. Audio DSP & Educational Content Copyright',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• All Piano notes, Guitar acoustic plucked strings, intervals, chord progressions, and mechanical metronome clicks (44.1kHz PCM WAV) are synthesized in-house via Solfa DSP algorithms.\n'
                        '• All music theory curricula and melodic exercises belong to universal music theory and Public Domain works.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '4. Voluntary Rewarded Ads Policy',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Solfa never displays forced pop-up or interstitial ads that interrupt lessons.\n'
                        '• Internet access is only used when you voluntarily choose to watch a short video in "Support Developer".',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '5. Virtual Reward Unit (Gem) Terms',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• "Gem" is a free in-app reward unit earned via daily goals, Battle Arena ranks, or voluntary support videos.\n'
                        '• Gems have NO real-world monetary value, cannot be purchased with real money, and cannot be cashed out or transferred.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '6. Anti-Tamper & Integrity Guard (SolfaIntegrityGuard)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Protected by SHA-256 salted checksum signatures and Monotonic Clock Guard against device clock rollback.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                    ]
                  : const [
                      Text(
                        '1. Bảo vệ dữ liệu cá nhân (Offline-First, GDPR & Nghị định 13)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Solfa hoạt động 100% ngoại tuyến (Offline-first) cho toàn bộ tính năng học tập Piano, Guitar và máy đếm nhịp.\n'
                        '• Ứng dụng KHÔNG yêu cầu đăng ký tài khoản, KHÔNG thu thập họ tên, email, vị trí GPS, danh bạ hay microphone.\n'
                        '• Lịch sử học tập và cài đặt chỉ lưu cục bộ trên thiết bị của bạn (SQLite) và có thể xóa vĩnh viễn bất kỳ lúc nào tại mục "Xóa dữ liệu lịch sử học tập" (tuân thủ Nghị định 13/2023/NĐ-CP, GDPR Châu Âu, CCPA Hoa Kỳ & Google Play Data Safety).',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '2. Quy định Chống chặn khu vực địa lý (EU) 2018/302 & Phân phối 174+ Quốc gia',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Tuân thủ Quy định (EU) 2018/302 của Nghị viện và Hội đồng Châu Âu về chống chặn theo khu vực địa lý (Geo-blocking Regulation), Solfa cung cấp quyền truy cập bình đẳng, không phân biệt quốc tịch hay nơi cư trú tại toàn bộ 27 quốc gia Liên minh Châu Âu (EU/EEA) và hơn 174 quốc gia/vùng lãnh thổ trên Google Play.\n'
                        '• Ứng dụng không giới hạn tính năng theo lãnh thổ và tự động hỗ trợ đa ngôn ngữ (Tiếng Việt & Tiếng Anh Quốc tế) dựa trên cài đặt vùng cục bộ của thiết bị.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '3. Bản quyền âm thanh & Nội dung học thuật',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Toàn bộ mẫu âm thanh nốt nhạc Piano, dây đàn Guitar Acoustic, quãng, vòng hòa âm và tiếng máy đếm nhịp cơ học (44.1kHz PCM WAV) được tổng hợp độc quyền bằng thuật toán xử lý tín hiệu số (DSP) của Solfa.\n'
                        '• Nội dung nhạc lý thuộc phạm vi kiến thức âm nhạc phổ quát và tác phẩm Public Domain, không sử dụng bản ghi âm có bản quyền của bên thứ ba.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '4. Chính sách Quảng cáo tự nguyện',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Solfa cam kết không hiển thị quảng cáo tự động gây gián đoạn bài học.\n'
                        '• Quyền kết nối Internet chỉ được sử dụng khi bạn chủ động bấm xem video tại mục "Hỗ trợ nhà phát triển".',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '5. Quy định Đơn vị thưởng ảo (Gem)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• "Gem" là đơn vị điểm thưởng nội bộ dùng để mở khóa phiên luyện tập chuyên sâu 1 tiếng (200 Gem), chế độ Tự do không giới hạn thời gian (350 Gem), tính năng Studio (300 Gem) hoặc đổi lượt Đấu Trường (từ 200 Gem).\n'
                        '• Gem hoàn toàn KHÔNG có giá trị tiền mặt, KHÔNG mua bán bằng tiền thật, KHÔNG chuyển nhượng và KHÔNG quy đổi/rút thành tiền dưới mọi hình thức.',
                        style: TextStyle(fontSize: 12.5, height: 1.42),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '6. Cơ chế Chống gian lận & Bảo vệ toàn vẹn (SolfaIntegrityGuard)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Ứng dụng tích hợp chữ ký băm (Salted Checksum Signature) bảo vệ số dư Gem, Sao xếp hạng và tiến độ nhiệm vụ cục bộ.\n'
                        '• Hệ thống kiểm tra đồng hồ đơn điệu (Monotonic Clock Guard) tự động phát hiện hành vi chỉnh lùi giờ thiết bị nhằm trục lợi nhiệm vụ hàng ngày.',
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
              child: Text(showEn ? 'Got it' : 'Đã hiểu'),
            ),
          ],
        ),
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
    final isEn = settings.isEnglish;
    final country = settings.detectedCountry;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isEn ? 'System Settings' : 'Cài đặt hệ thống'),
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
                                  'ChaoNote Studio v1.8.4',
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
                            isEn
                                ? 'Piano & Guitar Studio • 11 Topics • 174+ Countries'
                                : '7 chủ đề cảm âm & đọc khuông nhạc • Đàn C3–C5 • Guitar',
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

            // 0.5 Quốc gia & Ngôn ngữ (Region & Language + EU 2018/302)
            _SectionHeader(
              icon: Icons.public_rounded,
              title: isEn
                  ? 'Country, Region & Language'
                  : 'Quốc gia, Khu vực & Ngôn ngữ',
            ),
            const SizedBox(height: 8),
            Card(
              key: const Key('card_region_language'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            country.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${country.displayName(isEn)} (${country.countryCode})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.correct.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      settings.countryCodeOverride.isEmpty
                                          ? (isEn ? 'Auto Locale' : 'Tự động')
                                          : (isEn ? 'Selected' : 'Đã chọn'),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.correct,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${country.regulatoryRegion} • EU 2018/302 Ready',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('btn_select_country'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () => _showCountrySelectorModal(
                            context,
                            settings,
                            notifier,
                          ),
                          icon: const Icon(Icons.edit_location_alt_outlined,
                              size: 15),
                          label: Text(
                            isEn ? 'Region' : 'Đổi vùng',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isEn
                          ? 'Display Language & Music Notation'
                          : 'Ngôn ngữ hiển thị & Ký hiệu nhạc lý',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      key: const Key('segmented_language_mode'),
                      children: [
                        _DurationChoiceButton(
                          key: const Key('btn_lang_auto'),
                          label: isEn ? 'Auto (${country.countryCode})' : 'Tự động (${country.countryCode})',
                          isSelected: settings.languageMode == 'auto',
                          isDark: isDark,
                          onTap: () => notifier.setLanguageMode('auto'),
                        ),
                        const SizedBox(width: 6),
                        _DurationChoiceButton(
                          key: const Key('btn_lang_vi'),
                          label: '🇻🇳 Tiếng Việt',
                          isSelected: settings.languageMode == 'vi',
                          isDark: isDark,
                          onTap: () => notifier.setLanguageMode('vi'),
                        ),
                        const SizedBox(width: 6),
                        _DurationChoiceButton(
                          key: const Key('btn_lang_en'),
                          label: '🇬🇧 English',
                          isSelected: settings.languageMode == 'en',
                          isDark: isDark,
                          onTap: () => notifier.setLanguageMode('en'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Notation: Standard C - D - E - F - G - A - B (Solfège Do - Re - Mi)'
                                  : 'Ký hiệu: Song ngữ Đô - Rê - Mi - Fa - Sol - La - Si (C - D - E)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
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
            _SectionHeader(
              icon: Icons.palette_outlined,
              title: isEn
                  ? 'Theme & Appearance'
                  : 'Giao diện & Nền hiển thị',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Choose display mode (Light / Dark / System)'
                          : 'Chọn chế độ hình nền âm nhạc (Sáng / Tối)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      key: const Key('segmented_theme_mode'),
                      children: [
                        _ThemeModeCardButton(
                          label: isEn ? 'Light' : 'Nền Sáng',
                          icon: Icons.wb_sunny_rounded,
                          isSelected: settings.themeMode == ThemeMode.light,
                          isDark: isDark,
                          onTap: () => notifier.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeModeCardButton(
                          label: isEn ? 'Dark' : 'Nền Tối',
                          icon: Icons.nightlight_round,
                          isSelected: settings.themeMode == ThemeMode.dark,
                          isDark: isDark,
                          onTap: () => notifier.setThemeMode(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _ThemeModeCardButton(
                          label: isEn ? 'System' : 'Tự động',
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
            _SectionHeader(
              icon: Icons.headset_rounded,
              title: isEn
                  ? 'Practice Room Configuration'
                  : 'Cấu hình Phòng luyện tập',
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
                        Text(
                          isEn
                              ? 'Default practice duration'
                              : 'Thời gian luyện tập mặc định',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEn
                              ? 'Applied when starting a practice session'
                              : 'Áp dụng khi bắt đầu phiên luyện và tính điểm nốt đúng/sai',
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
                              label: isEn ? '60s' : '60 giây',
                              isSelected: selectedDuration == 60,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 60,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: isEn ? '15 min' : '15 phút',
                              isSelected: selectedDuration == 900,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 900,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: isEn ? '1h (50G)' : '1 tiếng (50G)',
                              isSelected: selectedDuration == 3600,
                              isDark: isDark,
                              onTap: () => ref
                                  .read(
                                      selectedPracticeDurationProvider.notifier)
                                  .state = 3600,
                            ),
                            const SizedBox(width: 6),
                            _DurationChoiceButton(
                              label: isEn ? 'Free (100G)' : 'Tự do (100G)',
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'Daily learning goal'
                              : 'Mục tiêu luyện tập hàng ngày',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEn
                              ? 'Number of questions per day to earn +20 Gems'
                              : 'Số nốt/câu trả lời mỗi ngày để hoàn thành mục tiêu',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          key: const Key('row_daily_goal_selector'),
                          children: [
                            for (final goal in const [10, 20, 30, 50]) ...[
                              if (goal != 10) const SizedBox(width: 6),
                              _DurationChoiceButton(
                                label: isEn ? '$goal notes' : '$goal nốt',
                                isSelected: settings.dailyGoalTarget == goal,
                                isDark: isDark,
                                onTap: () async {
                                  await notifier.setDailyGoalTarget(goal);
                                  ref.invalidate(overallProgressProvider);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('switch_unlock_all_levels'),
                    title: Text(
                      isEn
                          ? 'Unlock all difficulty levels'
                          : 'Mở khóa sẵn mọi cấp độ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Allow immediate access to Intermediate & Advanced levels'
                          : 'Cho phép vào ngay cấp Trung bình & Nâng cao',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: settings.unlockAllLevels,
                    onChanged: (v) => notifier.setUnlockAllLevels(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const Key('switch_auto_play'),
                    title: Text(
                      isEn
                          ? 'Auto-play question audio'
                          : 'Tự động phát âm thanh câu hỏi',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Automatically play the note when a new question appears'
                          : 'Tự phát nốt nhạc ngay khi chuyển sang câu hỏi mới',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: settings.autoPlayQuestionAudio,
                    onChanged: (v) => notifier.setAutoPlayAudio(v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Âm thanh & Máy đếm nhịp
            _SectionHeader(
              icon: Icons.volume_up_rounded,
              title: isEn
                  ? 'Audio & Mechanical Metronome'
                  : 'Âm thanh & Máy đếm nhịp cơ',
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
                            Expanded(
                              child: Text(
                                isEn
                                    ? 'Lesson & Feedback Volume'
                                    : 'Âm lượng bài học & Phản hồi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isEn ? 'Test Correct' : 'Thử âm Đúng',
                                  ),
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
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isEn ? 'Test C4 (Do)' : 'Thử nốt Đô (C4)',
                                  ),
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
                    title: Text(
                      isEn
                          ? 'Correct / Wrong sound effects'
                          : 'Âm báo phản hồi Đúng / Sai',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Play chime on correct answer and low tone on mistake'
                          : 'Phát chuông khi trả lời đúng và âm trầm khi sai',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: settings.feedbackSoundEnabled,
                    onChanged: (v) => notifier.setFeedbackSound(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(
                      isEn
                          ? 'Haptic vibration feedback'
                          : 'Rung phản hồi nhẹ (Haptic)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    value: settings.hapticFeedbackEnabled,
                    onChanged: (v) => notifier.setHapticFeedback(v),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'Default Metronome timbre'
                              : 'Âm sắc Metronome mặc định',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final item in [
                              ('tempo', 'Tempo Lite'),
                              ('click', isEn ? 'Mechanical' : 'Cơ học'),
                              ('woodblock', isEn ? 'Woodblock' : 'Gỗ trầm'),
                              ('bell', isEn ? 'Bell' : 'Chuông'),
                            ]) ...[
                              if (item.$1 != 'tempo') const SizedBox(width: 6),
                              _DurationChoiceButton(
                                label: item.$2,
                                isSelected:
                                    settings.defaultMetronomeSound == item.$1,
                                isDark: isDark,
                                onTap: () {
                                  notifier.setDefaultMetronomeSound(item.$1);
                                  ref
                                      .read(metronomeProvider.notifier)
                                      .setSoundType(item.$1);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(
                      isEn
                          ? 'Keep screen awake during Metronome'
                          : 'Giữ màn hình luôn sáng khi bật Metronome',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Prevent screen sleep while practicing rhythm'
                          : 'Ngăn điện thoại tự tắt màn hình khi đang giữ nhịp',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: settings.keepScreenAwakeOnMetronome,
                    onChanged: (v) => notifier.setKeepScreenAwake(v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Hỗ trợ, Quản lý dữ liệu & Pháp lý
            _SectionHeader(
              icon: Icons.favorite_rounded,
              title: isEn
                  ? 'Support Developer & Legal Compliance'
                  : 'Hỗ trợ Nhà phát triển & Pháp lý',
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
                      Expanded(
                        child: Text(
                          isEn ? 'Support Developer' : 'Hỗ trợ nhà phát triển',
                          style: const TextStyle(
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SolfaGemIcon(size: 12),
                            const SizedBox(width: 4),
                            Text(
                              adState.supportedCount > 0
                                  ? '${adState.supportedCount}x • ${adState.prestigePoints} Gem'
                                  : '${adState.prestigePoints} Gem',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: kHeartRedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isEn
                          ? 'Watch a short 15s voluntary video to earn +100 Gems & Supporter Badge'
                          : (adState.supportedCount > 0
                              ? 'Danh hiệu: ${adState.supporterBadgeTitle} • Bấm để nhận thêm Gem'
                              : 'Xem video ngắn 15s tự nguyện để nhận +100 Gem & Huy hiệu Tri Ân'),
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
                    key: const Key('tile_anti_tamper_status'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isEn
                          ? 'Anti-Tamper & Gem Integrity Guard'
                          : 'Bảo vệ chống gian lận & toàn vẹn Gem',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'SHA-256 salted signature & Monotonic Clock Guard: Active'
                          : 'Chữ ký số SHA-Salt & kiểm tra đồng hồ chống chỉnh giờ: Đang bật',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.correct.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isEn ? 'Secure' : 'An toàn',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.correct,
                        ),
                      ),
                    ),
                    onTap: () => _showPrivacyAndLegalDialog(
                      context,
                      initialEnglish: isEn,
                    ),
                  ),
                  const Divider(height: 1),
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
                    title: Text(
                      isEn
                          ? 'Privacy Policy & EU 2018/302 Legal Terms'
                          : 'Chính sách Quyền riêng tư & Pháp lý (EU 2018/302)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'GDPR, EU Geo-blocking 2018/302, Offline Data Safety & Gem Terms'
                          : 'Bảo vệ dữ liệu, Quy định EU 2018/302 (174+ quốc gia), Gem & bản quyền',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showPrivacyAndLegalDialog(
                      context,
                      initialEnglish: isEn,
                    ),
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
                    title: Text(
                      isEn
                          ? 'Open Source Licenses'
                          : 'Giấy phép mã nguồn mở',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Open source software libraries (MIT / BSD / Apache)'
                          : 'Danh mục thư viện phần mềm nguồn mở (MIT / BSD / Apache)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'ChaoNote Studio',
                      applicationVersion: '1.8.4 (Offline-First)',
                      applicationIcon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SolfaLogo(size: 56),
                      ),
                      applicationLegalese: isEn
                          ? '© 2026 ChaoNote Studio (Cháo Nhạc). 44.1kHz DSP audio synthesis and music theory content belong to ChaoNote.'
                          : '© 2026 ChaoNote Studio (Cháo Nhạc). Bản quyền âm thanh DSP 44.1kHz và nội dung nhạc lý thuộc về ChaoNote.',
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
                    title: Text(
                      isEn
                          ? 'Clear Learning History'
                          : 'Xóa dữ liệu lịch sử học tập',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.wrong,
                      ),
                    ),
                    subtitle: Text(
                      isEn
                          ? 'Reset all local scores, statistics, and review items'
                          : 'Đặt lại toàn bộ điểm số, thống kê và câu ôn tập',
                      style: const TextStyle(fontSize: 12),
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
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
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
    super.key,
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
