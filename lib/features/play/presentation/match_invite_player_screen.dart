import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/translation_service.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../../contacts/controller/contacts_controller.dart';
import '../../contacts/models/contact_models.dart';

class MatchInvitePlayerScreen extends ConsumerStatefulWidget {
  const MatchInvitePlayerScreen({super.key});

  @override
  ConsumerState<MatchInvitePlayerScreen> createState() =>
      _MatchInvitePlayerScreenState();
}

class _MatchInvitePlayerScreenState
    extends ConsumerState<MatchInvitePlayerScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          t('SCREEN.PLAY.INVITE_PLAYER', fallback: 'Inviter un joueur'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'SCREEN.PLAY.INVITE_PLAYER',
                        fallback: 'Selection du joueur',
                      ),
                      style: GoogleFonts.rajdhani(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'SCREEN.CONTACTS.SEARCH',
                        fallback: 'Choisissez un ami a ajouter a la partie en preparation.',
                      ),
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => ref
                          .read(contactsControllerProvider.notifier)
                          .searchUsers(value),
                      style: GoogleFonts.manrope(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: t(
                          'SCREEN.CONTACTS.SEARCH',
                          fallback: 'Rechercher un joueur',
                        ),
                        hintStyle: GoogleFonts.manrope(
                          color: AppColors.textHint,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: contacts.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface.withValues(alpha: 0.85),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.stroke.withValues(alpha: 0.9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.stroke.withValues(alpha: 0.9),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (contacts.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      contacts.error!,
                      style: GoogleFonts.manrope(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: contacts.isBootstrapping
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(contactsControllerProvider.notifier)
                            .refreshContacts(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          children: [
                            if (contacts.searchResults.isNotEmpty) ...[
                              _SectionTitle(
                                t(
                                  'SCREEN.CONTACTS.SEARCH',
                                  fallback: 'Resultats de recherche',
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...contacts.searchResults.map(
                                (player) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _InviteTile(
                                    player: player,
                                    onAction: () async {
                                      await ref
                                          .read(contactsControllerProvider.notifier)
                                          .selectFriend(player);
                                      if (context.mounted) {
                                        context.pop(player);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _SectionTitle(
                              t('SCREEN.CLUB.MEMBERS', fallback: 'Mes amis'),
                            ),
                            const SizedBox(height: 8),
                            if (contacts.friends.isEmpty)
                              _EmptyStateCard(
                                message:
                                  t('SCREEN.CONTACTS.NO_CONTACTS', fallback: 'Aucun ami disponible. Ajoutez un joueur puis revenez ici.'),
                                actionLabel: t('COMMON.CANCEL', fallback: 'Fermer'),
                                onAction: () => context.pop(),
                              ),
                            ...contacts.friends.map(
                              (friend) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _InviteTile(
                                  player: friend,
                                  onAction: () async {
                                    await ref
                                        .read(contactsControllerProvider.notifier)
                                        .selectFriend(friend);
                                    if (context.mounted) {
                                      context.pop(friend);
                                    }
                                  },
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.player,
    required this.onAction,
  });

  final ContactModel player;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.stroke.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: player.username,
            imageUrl: player.avatarUrl,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.username,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ELO ${player.elo}',
                  style: GoogleFonts.manrope(
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAction,
            tooltip: t('SCREEN.PLAY.INVITE_PLAYER', fallback: 'Ajouter a la partie'),
            icon: const Icon(
              Icons.add_box_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.stroke.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
