import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/solfa_logo.dart';
import '../providers/app_providers.dart';

/// Kết quả kiểm tra phiên bản mới trực tiếp từ Google Play Store (CH Play).
class PlayUpdateCheckResult {
  final bool updateAvailable;
  final bool inProgress;
  final bool immediateAllowed;
  final int availableVersionCode;
  final String? error;

  const PlayUpdateCheckResult({
    required this.updateAvailable,
    this.inProgress = false,
    this.immediateAllowed = false,
    this.availableVersionCode = 0,
    this.error,
  });

  factory PlayUpdateCheckResult.none([String? error]) => PlayUpdateCheckResult(
        updateAvailable: false,
        error: error,
      );

  factory PlayUpdateCheckResult.fromMap(Map<Object?, Object?> raw) {
    return PlayUpdateCheckResult(
      updateAvailable: raw['updateAvailable'] == true,
      inProgress: raw['inProgress'] == true,
      immediateAllowed: raw['immediateAllowed'] == true,
      availableVersionCode: (raw['availableVersionCode'] as num?)?.toInt() ?? 0,
      error: raw['error']?.toString(),
    );
  }
}

/// Giao diện trừu tượng giúp kiểm thử tự động 100% luồng khóa bắt buộc cập nhật CH Play.
abstract class PlayUpdatePlatformAdapter {
  Future<PlayUpdateCheckResult> checkForUpdate();
  Future<String> startImmediateUpdate();
  Future<bool> openPlayStoreListing();
}

class _MethodChannelPlayUpdateAdapter implements PlayUpdatePlatformAdapter {
  static const MethodChannel _channel =
      MethodChannel('vn.solfa.app.solfa/app_update');

  const _MethodChannelPlayUpdateAdapter();

  bool get _isAndroidMobile =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PlayUpdateCheckResult> checkForUpdate() async {
    if (!_isAndroidMobile) return PlayUpdateCheckResult.none('unsupported_os');
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('checkForUpdate');
      if (raw == null) return PlayUpdateCheckResult.none('empty_response');
      return PlayUpdateCheckResult.fromMap(raw);
    } catch (e) {
      return PlayUpdateCheckResult.none(e.toString());
    }
  }

  @override
  Future<String> startImmediateUpdate() async {
    if (!_isAndroidMobile) return 'unsupported_os';
    try {
      final status =
          await _channel.invokeMethod<String>('startImmediateUpdate');
      return status ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  @override
  Future<bool> openPlayStoreListing() async {
    if (!_isAndroidMobile) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('openPlayStoreListing');
      return opened == true;
    } catch (_) {
      return false;
    }
  }
}

/// Dịch vụ Kiểm tra & Bắt buộc Cập nhật qua CH Play (Google Play In-App Updates API - IMMEDIATE).
///
/// Nguyên tắc hoạt động an toàn & tuân thủ 100% chính sách duyệt ứng dụng Google Play:
/// - Khi người dùng đang Offline (không có mạng) hoặc đang ở bản mới nhất: cho phép học bình thường.
/// - Ngay khi máy có mạng và CH Play báo có bản mới hơn (`updateAvailable == true`):
///   1) Kích hoạt màn hình cập nhật bắt buộc chính chủ Google Play (`AppUpdateType.IMMEDIATE`).
///   2) Nếu người dùng bấm Back hủy giữa chừng hoặc thiết bị chưa mở được luồng nội tuyến,
///      hiển thị hộp thoại khóa cứng toàn màn hình (`PopScope(canPop: false)`) yêu cầu lên CH Play cập nhật,
///      không cho phép bỏ qua cho tới khi cập nhật hoàn tất.
class PlayStoreUpdateService {
  PlayStoreUpdateService._();

  static final PlayStoreUpdateService instance = PlayStoreUpdateService._();

  static const String kPlayStoreWebUrl =
      'https://play.google.com/store/apps/details?id=vn.solfa.app.solfa';

  PlayUpdatePlatformAdapter _adapter = const _MethodChannelPlayUpdateAdapter();

  bool _isChecking = false;
  bool _isForceDialogShowing = false;

  @visibleForTesting
  void setTestAdapter(PlayUpdatePlatformAdapter? adapter) {
    _adapter = adapter ?? const _MethodChannelPlayUpdateAdapter();
    _isChecking = false;
    _isForceDialogShowing = false;
  }

  @visibleForTesting
  bool get hasCustomTestAdapter => _adapter is! _MethodChannelPlayUpdateAdapter;

  Future<PlayUpdateCheckResult> checkForUpdate() => _adapter.checkForUpdate();

  Future<String> startImmediateUpdate() => _adapter.startImmediateUpdate();

  Future<bool> openPlayStoreListing() => _adapter.openPlayStoreListing();

  /// Tự động kiểm tra & khóa bắt buộc cập nhật nếu phát hiện bản mới trên CH Play.
  Future<void> enforceImmediateUpdateIfAvailable(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final isTest = ref.read(audioServiceProvider).isTestMode;
    if (isTest && !hasCustomTestAdapter) return;
    if (_isChecking || _isForceDialogShowing) return;

    _isChecking = true;
    try {
      final info = await _adapter.checkForUpdate();
      if (!info.updateAvailable) return;

      // Bước 1: Ưu tiên bung giao diện Immediate Update chính chủ của Google Play
      if (info.immediateAllowed) {
        final outcome = await _adapter.startImmediateUpdate();
        if (outcome == 'completed') {
          final recheck = await _adapter.checkForUpdate();
          if (!recheck.updateAvailable) return;
        }
      }

      // Bước 2: Nếu người dùng bấm Back hủy hoặc luồng nội tuyến bị đóng sớm -> Khóa bằng Cổng Cập Nhật CH Play
      if (!context.mounted || _isForceDialogShowing) return;
      _isForceDialogShowing = true;
      try {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.78),
          builder: (_) => ForceUpdateBlockingDialog(
            initialVersionCode: info.availableVersionCode,
          ),
        );
      } finally {
        _isForceDialogShowing = false;
      }
    } finally {
      _isChecking = false;
    }
  }
}

/// Cổng khóa bắt buộc cập nhật (Không thể bấm ra ngoài hay bấm nút Back vật lý để bỏ qua).
class ForceUpdateBlockingDialog extends ConsumerStatefulWidget {
  final int initialVersionCode;

  const ForceUpdateBlockingDialog({
    super.key,
    required this.initialVersionCode,
  });

  @override
  ConsumerState<ForceUpdateBlockingDialog> createState() =>
      _ForceUpdateBlockingDialogState();
}

class _ForceUpdateBlockingDialogState
    extends ConsumerState<ForceUpdateBlockingDialog>
    with WidgetsBindingObserver {
  bool _isBusy = false;
  late int _targetVersionCode;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    _targetVersionCode = widget.initialVersionCode;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckIfUpdated(silent: true);
    }
  }

  Future<void> _onTapUpdateNow(bool isEn) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusHint = null;
    });
    try {
      final svc = PlayStoreUpdateService.instance;
      final info = await svc.checkForUpdate();
      if (!info.updateAvailable) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      if (info.availableVersionCode > 0) {
        _targetVersionCode = info.availableVersionCode;
      }

      if (info.immediateAllowed) {
        final res = await svc.startImmediateUpdate();
        if (res == 'completed') {
          final after = await svc.checkForUpdate();
          if (!after.updateAvailable && mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            return;
          }
        } else if (res == 'canceled') {
          // Người dùng lại bấm hủy -> mở thẳng trang ứng dụng trên CH Play để bấm nút "Cập nhật"
          await svc.openPlayStoreListing();
        } else {
          await svc.openPlayStoreListing();
        }
      } else {
        await svc.openPlayStoreListing();
      }

      if (mounted) {
        setState(() {
          _statusHint = isEn
              ? 'Please complete the update on Google Play to continue.'
              : 'Vui lòng hoàn tất cập nhật trên CH Play để tiếp tục sử dụng ứng dụng.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _recheckIfUpdated({bool silent = false}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final isEn = ref.read(appSettingsProvider).isEnglish;
      final info = await PlayStoreUpdateService.instance.checkForUpdate();
      if (!mounted) return;
      if (!info.updateAvailable) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      if (info.availableVersionCode > 0) {
        _targetVersionCode = info.availableVersionCode;
      }
      if (!silent) {
        setState(() {
          _statusHint = isEn
              ? 'A newer version (#$_targetVersionCode) is still pending on Google Play. Tap "Update on Google Play" below!'
              : 'Trên CH Play vẫn còn bản mới hơn (#$_targetVersionCode) chưa cài đặt. Bạn hãy bấm "Cập nhật ngay trên CH Play" bên dưới nhé!';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = ref.watch(appSettingsProvider).isEnglish;

    return PopScope(
      canPop: false,
      child: Dialog(
        key: const Key('dialog_force_play_store_update'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppColors.primary.withOpacity(0.42),
            width: 1.5,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SolfaLogo(size: 52, showShadow: false),
                    Positioned(
                      right: -6,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.surfaceDark : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isEn
                    ? 'Update Required on Google Play'
                    : 'Đã Có Bản Cập Nhật Mới!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_targetVersionCode > 0) ...[
                const SizedBox(height: 5),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isEn
                          ? 'Google Play Build #$_targetVersionCode'
                          : 'Phiên bản CH Play mới: #$_targetVersionCode',
                      style: const TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Please update to the latest version on Google Play to sync new songs & features and continue learning.'
                    : 'Vui lòng cập nhật phiên bản mới nhất trên CH Play để đồng bộ tính năng mới và tiếp tục sử dụng ứng dụng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.6,
                  height: 1.38,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.correct.withOpacity(isDark ? 0.14 : 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.correct,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Gems, streaks & progress are 100% preserved.'
                            : 'Gem, chuỗi ngày & tiến trình giữ nguyên 100%.',
                        style: TextStyle(
                          fontSize: 11.3,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_statusHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  key: const Key('btn_force_update_now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isBusy ? null : () => _onTapUpdateNow(isEn),
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shop_rounded, size: 19),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isEn
                          ? 'Update Now on Google Play'
                          : 'Cập nhật ngay trên CH Play',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                key: const Key('btn_recheck_play_update'),
                onPressed: _isBusy ? null : () => _recheckIfUpdated(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    isEn
                        ? 'Already updated? Check again'
                        : 'Đã cập nhật xong? Kiểm tra lại',
                    style: const TextStyle(
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

