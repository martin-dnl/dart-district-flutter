import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/config/translation_service.dart';
import 'core/config/app_routes.dart';
import 'core/config/app_theme.dart';
import 'core/database/local_storage.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/version/version_gate.dart';
import 'features/match/controller/match_controller.dart';
import 'features/match/controller/ongoing_matches_controller.dart';
import 'features/match/models/match_model.dart';
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

  await TranslationService.instance.loadFromLocal();
  await LocalNotificationService.instance.initialize();
  final preferredLanguage =
      TranslationService.instance.currentLanguage.isNotEmpty
      ? TranslationService.instance.currentLanguage
      : await TranslationService.restorePreferredLanguage();
  Intl.defaultLocale = preferredLanguage;

  runApp(const ProviderScope(child: DartDistrictApp()));
}

class DartDistrictApp extends ConsumerStatefulWidget {
  const DartDistrictApp({super.key});

  @override
  ConsumerState<DartDistrictApp> createState() => _DartDistrictAppState();
}

class _DartDistrictAppState extends ConsumerState<DartDistrictApp> {
  StreamSubscription<InvitationNotificationAction>? _invitationActionSub;

  @override
  void initState() {
    super.initState();
    _invitationActionSub = LocalNotificationService.instance.invitationActions
        .listen(_handleInvitationAction);
  }

  @override
  void dispose() {
    _invitationActionSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInvitationAction(InvitationNotificationAction action) async {
    final controller = ref.read(ongoingMatchesControllerProvider.notifier);

    if (action.actionId == 'decline_invite') {
      await controller.refuseInvitation(action.matchId);
      return;
    }

    final acceptedMatch = await controller.acceptInvitation(action.matchId);
    if (acceptedMatch == null || !mounted) {
      return;
    }

    ref.read(matchControllerProvider.notifier).loadMatch(acceptedMatch);
    ref.read(routerProvider).push(_routeForMatch(acceptedMatch));
  }

  String _routeForMatch(MatchModel match) {
    final mode = match.mode.trim().toLowerCase();
    if (mode == 'cricket') {
      return AppRoutes.matchCricket;
    }
    if (mode == 'chasseur') {
      return AppRoutes.matchChasseur;
    }
    return AppRoutes.matchLive;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return ValueListenableBuilder<int>(
      valueListenable: TranslationService.revision,
      builder: (context, _, child) {
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
      },
    );
  }
}
