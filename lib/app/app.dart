import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SolfaScrollBehavior extends MaterialScrollBehavior {
  const SolfaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    );
  }
}

class SolfaApp extends ConsumerStatefulWidget {
  final GoRouter? customRouter;

  const SolfaApp({super.key, this.customRouter});

  @override
  ConsumerState<SolfaApp> createState() => _SolfaAppState();
}

class _SolfaAppState extends ConsumerState<SolfaApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.customRouter ?? createSolfaRouter();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'Solfa',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SolfaScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      routerConfig: _router,
    );
  }
}
