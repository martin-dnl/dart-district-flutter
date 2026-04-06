import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/controller/auth_controller.dart';
import '../../features/auth/presentation/not_logged_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/subscription_screen.dart';
import '../../features/auth/presentation/subscription_step1_screen.dart';
import '../../features/auth/presentation/subscription_step2_screen.dart';
import '../../features/auth/presentation/subscription_step3_screen.dart';
import '../../features/auth/presentation/sso_username_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/play/presentation/play_screen.dart';
import '../../features/play/presentation/x01_modes_screen.dart';
import '../../features/play/presentation/cricket_mode_screen.dart';
import '../../features/play/presentation/chasseur_mode_screen.dart';
import '../../features/play/presentation/game_setup_screen.dart';
import '../../features/play/presentation/match_invite_player_screen.dart';
import '../../features/play/presentation/qr_scan_screen.dart';
import '../../features/club/presentation/club_screen.dart';
import '../../features/club/presentation/club_detail_screen.dart';
import '../../features/club/presentation/club_create_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/contacts/presentation/contacts_chat_screen.dart';
import '../../features/contacts/models/contact_models.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/badges_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/match/presentation/match_live_screen.dart';
import '../../features/match/presentation/match_history_screen.dart';
import '../../features/match/presentation/match_report_screen.dart';
import '../../features/match/presentation/match_spectate_screen.dart';
import '../../features/match/presentation/cricket_match_screen.dart';
import '../../features/match/presentation/chasseur_match_screen.dart';
import '../../features/match/presentation/chasseur_zone_selection_screen.dart';
import '../../features/tournaments/presentation/tournaments_list_screen.dart';
import '../../features/tournaments/presentation/tournament_create_screen.dart';
import '../../features/tournaments/presentation/tournament_detail_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

class AppRoutes {
  AppRoutes._();

  static const String notLogged = '/notlogged';
  static const String login = '/login';
  static const String subscription = '/subscription';
  static const String subscriptionStep1 = '/subscription/step1';
  static const String subscriptionStep2 = '/subscription/step2';
  static const String subscriptionStep3 = '/subscription/step3';
  static const String home = '/home';
  static const String map = '/map';
  static const String play = '/play';
  static const String playX01 = '/play/x01';
  static const String playCricket = '/play/cricket';
  static const String playChasseur = '/play/chasseur';
  static const String gameSetup = '/play/setup';
  static const String gameInvitePlayer = '/play/setup/invite-player';
  static const String qrScan = '/play/qr-scan';
  static const String club = '/club';
  static const String clubDetail = '/club/:id';
  static const String clubCreate = '/club/create';
  static const String contacts = '/contacts';
  static const String contactsChat = '/contacts/chat';
  static const String tournaments = '/tournaments';
  static const String tournamentCreate = '/tournaments/create';
  static const String tournamentDetail = '/tournaments/:id';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';
  static const String about = '/profile/about';
  static const String badges = '/profile/badges';
  static const String matchLive = '/match';
  static const String matchCricket = '/match/cricket';
  static const String matchChasseur = '/match/chasseur';
  static const String matchChasseurZones = '/match/chasseur/zones';
  static const String matchHistory = '/match-history';
  static const String matchReport = '/match/:id/report';
  static const String matchSpectate = '/match/:id/spectate';
  static const String ssoUsernameSetup = '/onboarding/username';

  static const Set<String> publicRoutes = {
    notLogged,
    login,
    subscription,
    subscriptionStep1,
    subscriptionStep2,
    subscriptionStep3,
  };
}

/// Bridges Riverpod [AuthState] changes to GoRouter's [refreshListenable].
/// When auth state changes, GoRouter re-evaluates its redirect function
/// without recreating the router or resetting the navigation stack.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final isPublic = AppRoutes.publicRoutes.contains(state.matchedLocation);
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final isInitializing =
        authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading;
    final needsUsername = authState.status == AuthStatus.needsUsernameSetup;

    // While restoring session, keep auth pages but block protected ones.
    if (isInitializing) {
      return isPublic ? null : AppRoutes.notLogged;
    }

    // SSO new user: must pick a username before accessing the app.
    if (needsUsername) {
      const onboardingRoutes = {
        AppRoutes.subscriptionStep1,
        AppRoutes.subscriptionStep2,
      };
      return onboardingRoutes.contains(state.matchedLocation)
          ? null
          : AppRoutes.subscriptionStep1;
    }

    // Not logged in trying to access a protected route.
    if (!isAuthenticated && !isPublic) {
      return AppRoutes.notLogged;
    }

    // Logged-in user cannot visit public (auth) pages.
    if (isAuthenticated && isPublic) {
      if (state.matchedLocation == AppRoutes.subscriptionStep3) {
        return null;
      }
      return AppRoutes.home;
    }

    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Single [GoRouter] instance for the lifetime of the app.
/// Navigation guards are driven by [_RouterNotifier] via [refreshListenable].
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.notLogged,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Public / auth routes ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.notLogged,
        builder: (_, _) => const NotLoggedScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (_, _) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscriptionStep1,
        builder: (_, state) {
          final payload =
              state.extra as Map<String, dynamic>? ?? const <String, dynamic>{};
          return SubscriptionStep1Screen(payload: payload);
        },
      ),
      GoRoute(
        path: AppRoutes.subscriptionStep2,
        builder: (_, state) {
          final payload =
              state.extra as Map<String, dynamic>? ?? const <String, dynamic>{};
          return SubscriptionStep2Screen(payload: payload);
        },
      ),
      GoRoute(
        path: AppRoutes.subscriptionStep3,
        builder: (_, _) => const SubscriptionStep3Screen(),
      ),
      GoRoute(
        path: AppRoutes.ssoUsernameSetup,
        builder: (_, _) => const SsoUsernameScreen(),
      ),
      // ── Protected shell routes (bottom nav) ───────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, _, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.map,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const MapScreen()),
          ),
          GoRoute(
            path: AppRoutes.play,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const PlayScreen()),
          ),
          GoRoute(
            path: AppRoutes.club,
            pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ClubScreen()),
          ),
          GoRoute(
            path: AppRoutes.contacts,
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ContactsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.tournaments,
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const TournamentsListScreen(),
            ),
          ),
        ],
      ),
      // ── Protected full-screen routes (displayed above shell) ──────────────
      GoRoute(
        path: AppRoutes.gameSetup,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final mode = state.extra as String? ?? '501';
          return NoTransitionPage(
            key: state.pageKey,
            child: GameSetupScreen(gameMode: mode),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.playX01,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const X01ModesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.playCricket,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CricketModeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.playChasseur,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ChasseurModeScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.gameInvitePlayer,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const MatchInvitePlayerScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.qrScan,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final scanMode = (extra?['mode'] ?? QrScanMode.user.name).toString();
          final mode = scanMode == QrScanMode.club.name
              ? QrScanMode.club
              : QrScanMode.user;
          return NoTransitionPage(
            key: state.pageKey,
            child: QrScanScreen(mode: mode),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.matchLive,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const MatchLiveScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.matchCricket,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const CricketMatchScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.matchChasseur,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ChasseurMatchScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.matchChasseurZones,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ChasseurZoneSelectionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final userId = state.extra as String?;
          return NoTransitionPage(
            key: state.pageKey,
            child: ProfileScreen(userId: userId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.matchHistory,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const MatchHistoryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.matchReport,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final matchId = state.pathParameters['id'] ?? '';
          return NoTransitionPage(
            key: state.pageKey,
            child: MatchReportScreen(matchId: matchId, extra: state.extra),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.matchSpectate,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final matchId = state.pathParameters['id'] ?? '';
          return NoTransitionPage(
            key: state.pageKey,
            child: MatchSpectateScreen(matchId: matchId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.clubCreate,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ClubCreateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.clubDetail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          return NoTransitionPage(
            key: state.pageKey,
            child: ClubDetailScreen(id: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tournamentCreate,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const TournamentCreateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.tournamentDetail,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final tournamentId = state.pathParameters['id'] ?? '';
          return NoTransitionPage(
            key: state.pageKey,
            child: TournamentDetailScreen(tournamentId: tournamentId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) =>
            NoTransitionPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) =>
        NoTransitionPage(key: state.pageKey, child: const AboutScreen()),
      ),
      GoRoute(
        path: AppRoutes.badges,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) =>
            NoTransitionPage(key: state.pageKey, child: const BadgesScreen()),
      ),
      GoRoute(
        path: AppRoutes.contactsChat,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final contact = state.extra;
          if (contact is ContactModel) {
            return NoTransitionPage(
              key: ValueKey('${state.pageKey}-chat-${contact.id}'),
              child: ContactsChatScreen(contact: contact),
            );
          }
          return NoTransitionPage(
            key: state.pageKey,
            child: const Scaffold(
              body: Center(child: Text('Contact introuvable')),
            ),
          );
        },
      ),
    ],
  );
});
