import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../../auth/controller/auth_controller.dart';
import '../../play/presentation/qr_scan_screen.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/player_avatar.dart';
import '../controller/contacts_controller.dart';
import '../models/contact_models.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  late final TextEditingController _searchController;

  Future<void> _scanUserQrAndOpenProfile() async {
    final result = await context.push<Object?>(
      AppRoutes.qrScan,
      extra: {'mode': QrScanMode.user.name},
    );

    if (!mounted || result == null) {
      return;
    }

    String? userId;
    if (result is ContactModel) {
      userId = result.id;
    } else if (result is Map<String, dynamic>) {
      userId = result['id']?.toString();
    }

    if (userId == null || userId.isEmpty) {
      return;
    }

    context.push(AppRoutes.profile, extra: userId);
  }

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
    final isGuest = (ref.watch(currentUserProvider)?.isGuest ?? false);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.pageGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      contacts.isConnected
                          ? 'Connecté'
                          : 'Hors ligne',
                      style: GoogleFonts.manrope(
                        color: contacts.isConnected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref
                        .read(contactsControllerProvider.notifier)
                        .refreshContacts(),
                    tooltip: 'Rafraichir',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: contacts.isConnected
                          ? AppColors.primary
                          : AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: _SearchBox(
                controller: _searchController,
                isLoading: contacts.isSearching,
                onChanged: (value) => ref
                    .read(contactsControllerProvider.notifier)
                    .searchUsers(value),
                onScanQr: _scanUserQrAndOpenProfile,
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
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
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
                            _SectionTitle('Resultats de recherche'),
                            const SizedBox(height: 8),
                            ...contacts.searchResults.map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SearchResultTile(
                                  contact: c,
                                  canAdd: !isGuest,
                                  onOpenProfile: () => context.push(
                                    AppRoutes.profile,
                                    extra: c.id,
                                  ),
                                  onAdd: () => ref
                                      .read(contactsControllerProvider.notifier)
                                      .addFriend(c),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (contacts.incomingRequests.isNotEmpty) ...[
                            _SectionTitle('Demandes recues'),
                            const SizedBox(height: 8),
                            ...contacts.incomingRequests.map(
                              (request) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _IncomingRequestTile(
                                  request: request,
                                  onOpenProfile: () => context.push(
                                    AppRoutes.profile,
                                    extra: request.user.id,
                                  ),
                                  onAccept: () => ref
                                      .read(contactsControllerProvider.notifier)
                                      .acceptFriendRequest(request),
                                  onReject: () => ref
                                      .read(contactsControllerProvider.notifier)
                                      .rejectFriendRequest(request),
                                  onBlock: () => ref
                                      .read(contactsControllerProvider.notifier)
                                      .blockUser(request.user.id),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          if (contacts.outgoingRequests.isNotEmpty) ...[
                            _SectionTitle('Demandes en attente'),
                            const SizedBox(height: 8),
                            ...contacts.outgoingRequests.map(
                              (request) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OutgoingRequestTile(
                                  request: request,
                                  onOpenProfile: () => context.push(
                                    AppRoutes.profile,
                                    extra: request.user.id,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          _SectionTitle('Amis'),
                          const SizedBox(height: 8),
                          if (contacts.friends.isEmpty)
                            const _EmptyStateCard(
                              message:
                                  'Aucun ami pour le moment. Recherchez un joueur pour commencer.',
                            ),
                          ...contacts.friends.map(
                            (friend) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FriendTile(
                                friend: friend,
                                unreadCount:
                                    contacts.unreadByContact[friend.id] ?? 0,
                                onOpenProfile: () => context.push(
                                  AppRoutes.profile,
                                  extra: friend.id,
                                ),
                                onChallenge: () {
                                  ref
                                      .read(contactsControllerProvider.notifier)
                                      .selectFriend(friend);
                                  context.go(AppRoutes.play);
                                },
                                onOpenChat: () async {
                                  await ref
                                      .read(contactsControllerProvider.notifier)
                                      .selectFriend(friend);
                                  if (context.mounted) {
                                    context.push(
                                      AppRoutes.contactsChat,
                                      extra: friend,
                                    );
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

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
    required this.onScanQr,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.manrope(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Rechercher un joueur',
        hintStyle: GoogleFonts.manrope(color: AppColors.textHint),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        suffixIcon: SizedBox(
          width: 74,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: onScanQr,
                tooltip: 'Scanner QR',
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.contact,
    required this.canAdd,
    required this.onOpenProfile,
    required this.onAdd,
  });

  final ContactModel contact;
  final bool canAdd;
  final VoidCallback onOpenProfile;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          PlayerAvatar(
            name: contact.username,
            imageUrl: contact.avatarUrl,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Text(
                contact.username,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(
            'ELO ${contact.elo}',
            style: GoogleFonts.manrope(
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          if (canAdd)
            IconButton(
              onPressed: onAdd,
              tooltip: 'Ajouter',
              icon: const Icon(
                Icons.add_box_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({
    required this.request,
    required this.onOpenProfile,
    required this.onAccept,
    required this.onReject,
    required this.onBlock,
  });

  final FriendRequestModel request;
  final VoidCallback onOpenProfile;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(
                name: request.user.username,
                imageUrl: request.user.avatarUrl,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: Text(
                    '${request.user.username} veut vous ajouter',
                    style: GoogleFonts.manrope(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context: context,
                    title: 'Bloquer ${request.user.username} ?',
                    message: 'Cet utilisateur ne pourra plus vous contacter.',
                    confirmLabel: 'Bloquer',
                    confirmColor: AppColors.error,
                  );
                  if (confirmed) {
                    onBlock();
                  }
                },
                icon: const Icon(Icons.block, color: AppColors.error, size: 20),
                tooltip: 'Bloquer',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('Accepter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingRequestTile extends StatelessWidget {
  const _OutgoingRequestTile({
    required this.request,
    required this.onOpenProfile,
  });

  final FriendRequestModel request;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          PlayerAvatar(
            name: request.user.username,
            imageUrl: request.user.avatarUrl,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Text(
                request.user.username,
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(
            'Envoyee',
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.unreadCount,
    required this.onOpenProfile,
    required this.onChallenge,
    required this.onOpenChat,
  });

  final ContactModel friend;
  final int unreadCount;
  final VoidCallback onOpenProfile;
  final VoidCallback onChallenge;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Row(
                children: [
                  PlayerAvatar(
                    name: friend.username,
                    imageUrl: friend.avatarUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      friend.username,
                      style: GoogleFonts.manrope(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.sports_esports,
              color: AppColors.primary,
              size: 20,
            ),
            tooltip: 'Defier',
            onPressed: onChallenge,
          ),
          IconButton(
            onPressed: onOpenChat,
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            tooltip: 'Message',
          ),
        ],
      ),
    );
  }
}

class _BaseTile extends StatelessWidget {
  const _BaseTile({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? AppColors.stroke),
      ),
      child: child,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Text(
        message,
        style: GoogleFonts.manrope(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
