import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../controller/contacts_controller.dart';
import '../models/contact_models.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
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

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.pageGradient),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contacts',
                          style: GoogleFonts.rajdhani(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contacts.isConnected
                              ? 'Connecte en temps reel'
                              : 'Connexion realtime en attente',
                          style: GoogleFonts.manrope(
                            color: contacts.isConnected
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: contacts.isConnected
                          ? AppColors.success
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
                  : ListView(
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
                                onAccept: () => ref
                                    .read(contactsControllerProvider.notifier)
                                    .acceptFriendRequest(request),
                                onReject: () => ref
                                    .read(contactsControllerProvider.notifier)
                                    .rejectFriendRequest(request),
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
                              child: _OutgoingRequestTile(request: request),
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
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onChanged;

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
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.contact, required this.onAdd});

  final ContactModel contact;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          _AvatarLetter(name: contact.username),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contact.username,
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
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
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestTile extends StatelessWidget {
  const _IncomingRequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequestModel request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AvatarLetter(name: request.user.username),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${request.user.username} veut vous ajouter',
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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
  const _OutgoingRequestTile({required this.request});

  final FriendRequestModel request;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          _AvatarLetter(name: request.user.username),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'En attente: ${request.user.username}',
              style: GoogleFonts.manrope(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
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
    required this.onChallenge,
    required this.onOpenChat,
  });

  final ContactModel friend;
  final int unreadCount;
  final VoidCallback onChallenge;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return _BaseTile(
      child: Row(
        children: [
          _AvatarLetter(name: friend.username),
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
          ElevatedButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  const _AvatarLetter({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.surfaceLight,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
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
