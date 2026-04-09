import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/config/translation_service.dart';
import 'core/config/app_routes.dart';
import 'core/config/app_theme.dart';
import 'core/database/local_storage.dart';
import 'core/version/version_gate.dart';
import 'features/match/widgets/match_invitation_overlay.dart';

bool _isBenignMapCancellation(Object error, StackTrace stackTrace) {
  final errorText = error.toString().toLowerCase();
  final stackText = stackTrace.toString().toLowerCase();

  final isCancelled = errorText.contains('cancelled');
  final fromVectorTiles =
      stackText.contains('vector_map_tiles') ||
      stackText.contains('executor_lib/src/isolate_executor.dart') ||
      stackText.contains('executor_lib/src/pool_executor.dart');

  return isCancelled && fromVectorTiles;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    final stack = details.stack ?? StackTrace.current;
    if (_isBenignMapCancellation(details.exception, stack)) {
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    if (_isBenignMapCancellation(error, stackTrace)) {
      return true;
    }
    return false;
  };

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Init local storage
  await LocalStorage.init();

  final preferredLanguage = await TranslationService.restorePreferredLanguage();
  Intl.defaultLocale = preferredLanguage;

  runApp(const ProviderScope(child: DartDistrictApp()));
}

class DartDistrictApp extends ConsumerWidget {
  const DartDistrictApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Dart District',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return VersionGate(
          child: MatchInvitationOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
