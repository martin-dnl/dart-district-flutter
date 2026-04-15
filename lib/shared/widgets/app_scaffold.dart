import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_colors.dart';
import '../../core/config/app_routes.dart';
import '../../core/network/connectivity_status.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../../features/contacts/controller/contacts_controller.dart';
import '../../features/match/controller/ongoing_matches_controller.dart';
import '../../features/notifications/controller/notifications_controller.dart';
import 'player_avatar.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.map)) return 1;
    if (location.startsWith(AppRoutes.play)) return 2;
    if (location.startsWith(AppRoutes.club)) return 3;
    if (location.startsWith(AppRoutes.contactsChat)) return 4;
    if (location.startsWith(AppRoutes.contacts)) return 4;
    if (location.startsWith(AppRoutes.tournaments)) return 5;
    return -1;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.map);
      case 2:
        context.go(AppRoutes.play);
      case 3:
        context.go(AppRoutes.club);
      case 4:
        context.go(AppRoutes.contacts);
      case 5:
        context.go(AppRoutes.tournaments);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final location = GoRouterState.of(context).uri.path;
    final user = ref.watch(currentUserProvider);
    final unreadContacts = ref.watch(contactsUnreadCountProvider);
    final unreadNotifications = ref.watch(notificationsUnreadCountProvider);
    final ongoingMatchCount = ref
        .watch(ongoingMatchesControllerProvider)
        .matches
        .length;
    final isOffline = ref
        .watch(isOfflineProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    final showPageHeader = _shouldShowPageHeader(location);
    final pageTitle = _pageTitle(location);

    const items = <({IconData icon, String label})>[
      (icon: Icons.home_rounded, label: 'Accueil'),
      (icon: Icons.map_rounded, label: 'Carte'),
      (icon: Icons.gps_fixed, label: 'Jouer'),
      (icon: Icons.groups_rounded, label: 'Club'),
      (icon: Icons.forum_rounded, label: 'Contacts'),
      (icon: Icons.emoji_events_rounded, label: 'Tournois'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: Column(
          children: [
            if (showPageHeader)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => context.push(AppRoutes.profile),
                        child: PlayerAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.username ?? 'Joueur',
                          size: 40,
                          showBorder: true,
                          borderColor: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pageTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () =>
                            GoRouter.of(context).go(AppRoutes.socialFeed),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.rss_feed_rounded,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () =>
                            GoRouter.of(context).go(AppRoutes.notifications),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.stroke),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.notifications_none,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (unreadNotifications > 0)
                                Positioned(
                                  right: -2,
                                  top: -3,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadNotifications > 99
                                            ? '99+'
                                            : '$unreadNotifications',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: isOffline ? 34 : 0,
              curve: Curves.easeOutCubic,
              width: double.infinity,
              child: isOffline
                  ? Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: AppColors.warning,
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Mode hors ligne',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  AppColors.surface.withValues(alpha: 0.92),
                  AppColors.card.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.stroke.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _DockItem(
                      icon: items[i].icon,
                      label: items[i].label,
                      badgeCount: i == 2
                          ? ongoingMatchCount
                          : (i == 4 ? unreadContacts : 0),
                      selected: i == currentIndex,
                      onTap: () => _onTap(context, i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowPageHeader(String location) {
    if (location.startsWith(AppRoutes.home)) return false;
    if (location.startsWith(AppRoutes.profile)) return false;
    return true;
  }

  String _pageTitle(String location) {
    if (location.startsWith(AppRoutes.map)) return 'Carte';
    if (location.startsWith(AppRoutes.play)) return 'Jouer';
    if (location.startsWith(AppRoutes.club)) return 'Club';
    if (location.startsWith(AppRoutes.contactsChat)) return 'Chat';
    if (location.startsWith(AppRoutes.contacts)) return 'Contacts';
    if (location.startsWith(AppRoutes.tournaments)) return 'Tournois';
    if (location.startsWith(AppRoutes.socialFeed)) return 'Social';
    if (location.startsWith(AppRoutes.notifications)) return 'Notifications';
    return 'Dart District';
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: selected ? AppColors.ctaGradient : null,
        color: selected ? null : Colors.transparent,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: selected
                            ? AppColors.background
                            : AppColors.textSecondary,
                      ),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      builder: (context, color, _) {
                        return Icon(icon, size: 26, color: color);
                      },
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -9,
                        top: -8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.background
                                : AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
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
        ),
      ),
    );
  }
}
