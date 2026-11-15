import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch synchronous Flutter framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Friendly fallback UI if a widget ever fails to build in production
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Material(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Đã xảy ra gián đoạn hiển thị tạm thời. Vui lòng thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  };

  // Catch asynchronous platform/plugin exceptions (e.g. audio focus, wakelock, connectivity)
  // so they never crash the application process on mobile devices.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught platform error handled safely: $error');
    return true;
  };

  runApp(
    const ProviderScope(
      child: SolfaApp(),
    ),
  );
}
