import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_routes.dart';
import 'core/config/app_theme.dart';
import 'core/database/local_storage.dart';
import 'core/version/version_gate.dart';
import 'features/match/widgets/match_invitation_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
