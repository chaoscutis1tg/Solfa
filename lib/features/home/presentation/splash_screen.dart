import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/animated_ui.dart';
import '../../../app/widgets/solfa_background.dart';
import '../../../app/widgets/solfa_logo.dart';
import '../../../core/providers/app_providers.dart';

/// UI-01: Splash / Khởi động
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final db = ref.read(appDatabaseProvider);
      await db.seedContent();
      await ref.read(appSettingsProvider.notifier).loadSettings();
      ref.invalidate(topicsListProvider);
      ref.invalidate(overallProgressProvider);
      ref.invalidate(pendingReviewItemsProvider);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError =
            'Không thể khởi tạo cơ sở dữ liệu cục bộ. Vui lòng thử lại. ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SolfaBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SolfaLogo(size: 168, showShadow: false),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0E1A48).withOpacity(0.82)
                            : Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        'Luyện Cảm Âm • Nhạc Lý • Metronome',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_initError == null)
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    else ...[
                      Text(
                        _initError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.wrong),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _initError = null);
                          _initializeApp();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử khởi tạo lại'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
