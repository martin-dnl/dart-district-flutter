import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../data/contacts_realtime_service.dart';
import '../data/contacts_repository.dart';
import '../models/contact_models.dart';

class ContactsState {
  const ContactsState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.searchResults = const [],
    this.selectedFriend,
    this.messagesByContact = const {},
    this.unreadByContact = const {},
    this.isConnected = false,
    this.isSearching = false,
    this.isBootstrapping = false,
    this.error,
  });

  final List<ContactModel> friends;
  final List<FriendRequestModel> incomingRequests;
  final List<FriendRequestModel> outgoingRequests;
  final List<ContactModel> searchResults;
  final ContactModel? selectedFriend;
  final Map<String, List<ContactMessage>> messagesByContact;
  final Map<String, int> unreadByContact;
  final bool isConnected;
  final bool isSearching;
  final bool isBootstrapping;
  final String? error;

  int get unreadTotal => unreadByContact.values.fold(0, (a, b) => a + b);

  List<ContactMessage> messagesForSelected() {
    final selected = selectedFriend;
    if (selected == null) return const [];
    return messagesByContact[selected.id] ?? const [];
  }

  ContactsState copyWith({
    List<ContactModel>? friends,
    List<FriendRequestModel>? incomingRequests,
    List<FriendRequestModel>? outgoingRequests,
    List<ContactModel>? searchResults,
    ContactModel? selectedFriend,
    bool clearSelectedFriend = false,
    Map<String, List<ContactMessage>>? messagesByContact,
    Map<String, int>? unreadByContact,
    bool? isConnected,
    bool? isSearching,
    bool? isBootstrapping,
    String? error,
    bool clearError = false,
  }) {
    return ContactsState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      searchResults: searchResults ?? this.searchResults,
      selectedFriend: clearSelectedFriend
          ? null
          : (selectedFriend ?? this.selectedFriend),
      messagesByContact: messagesByContact ?? this.messagesByContact,
      unreadByContact: unreadByContact ?? this.unreadByContact,
      isConnected: isConnected ?? this.isConnected,
      isSearching: isSearching ?? this.isSearching,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ContactsController extends StateNotifier<ContactsState> {
  ContactsController({
    required this.repository,
    required this.realtime,
    required this.currentUserId,
  }) : super(const ContactsState()) {
    if (currentUserId != null && currentUserId!.isNotEmpty) {
      _bootstrap();
      realtime.connect(userId: currentUserId!);
      _messageSub = realtime.messageStream.listen(_onSocketMessage);
      _connectionSub = realtime.connectionStream.listen((connected) {
        state = state.copyWith(isConnected: connected, clearError: true);
      });
    }
  }

  final ContactsRepository repository;
  final ContactsRealtimeService realtime;
  final String? currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;
  StreamSubscription<bool>? _connectionSub;

  Future<void> _bootstrap() async {
    state = state.copyWith(isBootstrapping: true, clearError: true);
    try {
      await refreshContacts();
      state = state.copyWith(isBootstrapping: false);
    } catch (_) {
      state = state.copyWith(
        isBootstrapping: false,
        error: 'Impossible de charger les contacts.',
      );
    }
  }

  Future<void> refreshContacts() async {
    final friendsFuture = repository.fetchFriends();
    final unreadFuture = repository.fetchUnreadByContact();
    final incomingFuture = repository.fetchIncomingRequests();
    final outgoingFuture = repository.fetchOutgoingRequests();

    final friends = await friendsFuture;
    final unreadByContact = await unreadFuture;
    final incoming = await incomingFuture;
    final outgoing = await outgoingFuture;

    final enrichedFriends = friends
        .map(
          (friend) => friend.copyWith(
            unreadCount: unreadByContact[friend.id] ?? friend.unreadCount,
          ),
        )
        .toList();

    final filteredResults = _filterSearchResults(
      state.searchResults,
      friends: enrichedFriends,
      incomingRequests: incoming,
      outgoingRequests: outgoing,
    );

    state = state.copyWith(
      friends: enrichedFriends,
      incomingRequests: incoming,
      outgoingRequests: outgoing,
      unreadByContact: unreadByContact,
      searchResults: filteredResults,
      clearError: true,
    );
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: const [], clearError: true);
      return;
    }

    state = state.copyWith(isSearching: true, clearError: true);
    try {
      final results = await repository.searchUsers(query);
      final filteredResults = _filterSearchResults(
        results,
        friends: state.friends,
        incomingRequests: state.incomingRequests,
        outgoingRequests: state.outgoingRequests,
      );
      state = state.copyWith(
        isSearching: false,
        searchResults: filteredResults,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isSearching: false,
        error: 'Recherche indisponible pour le moment.',
      );
    }
  }

  Future<void> addFriend(ContactModel friend) async {
    final exists = state.friends.any((f) => f.id == friend.id);
    if (exists) {
      await selectFriend(friend);
      return;
    }

    try {
      final status = await repository.sendFriendRequest(friend.id);

      if (status == 'accepted' || status == 'already_friends') {
        final refreshedFriends = await repository.fetchFriends();
        state = state.copyWith(
          friends: refreshedFriends,
          selectedFriend: refreshedFriends.firstWhere(
            (f) => f.id == friend.id,
            orElse: () => friend,
          ),
          clearError: true,
        );
        await _loadConversation(friend.id);
        await _refreshRequests();
        return;
      }

      await _refreshRequests();
      state = state.copyWith(
        clearError: true,
        error: 'Demande d\'ami envoyee a ${friend.username}.',
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Impossible d\'envoyer la demande pour le moment.',
      );
    }
  }

  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    try {
      await repository.acceptRequest(request.id);
      final refreshedFriends = await repository.fetchFriends();
      await _refreshRequests();
      state = state.copyWith(
        friends: refreshedFriends,
        selectedFriend: request.user,
        clearError: true,
      );
      await _loadConversation(request.user.id);
      await _markRead(request.user.id);
    } catch (_) {
      state = state.copyWith(error: 'Impossible d\'accepter la demande.');
    }
  }

  Future<void> rejectFriendRequest(FriendRequestModel request) async {
    try {
      await repository.rejectRequest(request.id);
      await _refreshRequests();
      state = state.copyWith(clearError: true);
    } catch (_) {
      state = state.copyWith(error: 'Impossible de refuser la demande.');
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await repository.blockUser(userId);
      state = state.copyWith(
        friends: state.friends.where((f) => f.id != userId).toList(),
        incomingRequests: state.incomingRequests
            .where((r) => r.user.id != userId)
            .toList(),
        outgoingRequests: state.outgoingRequests
            .where((r) => r.user.id != userId)
            .toList(),
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(error: 'Impossible de bloquer cet utilisateur.');
    }
  }

  Future<void> selectFriend(ContactModel friend) async {
    state = state.copyWith(selectedFriend: friend, clearError: true);
    await _loadConversation(friend.id);
    await _markRead(friend.id);
  }

  void clearSelectedFriend() {
    state = state.copyWith(clearSelectedFriend: true, clearError: true);
  }

  void sendMessage(String rawText) {
    final fromUserId = currentUserId;
    final selected = state.selectedFriend;
    final text = rawText.trim();
    if (fromUserId == null ||
        fromUserId.isEmpty ||
        selected == null ||
        text.isEmpty) {
      return;
    }

    final optimistic = ContactMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      fromUserId: fromUserId,
      toUserId: selected.id,
      content: text,
      createdAt: DateTime.now(),
      isLocalEcho: true,
    );

    final currentMessages = state.messagesByContact[selected.id] ?? const [];
    state = state.copyWith(
      messagesByContact: {
        ...state.messagesByContact,
        selected.id: [...currentMessages, optimistic],
      },
      clearError: true,
    );

    realtime.sendDirectMessage(
      fromUserId: fromUserId,
      toUserId: selected.id,
      content: text,
    );
  }

  void _onSocketMessage(Map<String, dynamic> payload) {
    final selfId = currentUserId;
    if (selfId == null || selfId.isEmpty) {
      return;
    }

    final message = ContactMessage.fromSocket(payload);
    if (message.content.isEmpty) {
      return;
    }

    final peerId = message.fromUserId == selfId
        ? message.toUserId
        : message.fromUserId;
    if (peerId.isEmpty) {
      return;
    }

    final currentMessages = state.messagesByContact[peerId] ?? const [];
    final isDuplicate =
        currentMessages.isNotEmpty &&
        currentMessages.any((m) => m.id.isNotEmpty && m.id == message.id);
    if (isDuplicate) {
      return;
    }

    if (message.fromUserId == selfId) {
      final optimisticIndex = currentMessages.indexWhere(
        (m) =>
            m.isLocalEcho &&
            m.toUserId == message.toUserId &&
            m.content == message.content &&
            message.createdAt.difference(m.createdAt).inSeconds.abs() <= 3,
      );

      if (optimisticIndex >= 0) {
        final reconciled = [...currentMessages];
        reconciled[optimisticIndex] = message;
        reconciled.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(
          messagesByContact: {...state.messagesByContact, peerId: reconciled},
          clearError: true,
        );
        return;
      }
    }

    final nextMessages = [...currentMessages, message]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    var nextFriends = state.friends;
    final alreadyKnown = nextFriends.any((f) => f.id == peerId);
    if (!alreadyKnown) {
      nextFriends = [
        ...nextFriends,
        ContactModel(id: peerId, username: 'Joueur $peerId'),
      ];
    }

    final selectedId = state.selectedFriend?.id;
    final isIncoming = message.fromUserId == peerId;
    var nextUnread = state.unreadByContact;

    if (isIncoming && selectedId != peerId) {
      nextUnread = {...nextUnread, peerId: (nextUnread[peerId] ?? 0) + 1};
    }

    state = state.copyWith(
      friends: nextFriends,
      messagesByContact: {...state.messagesByContact, peerId: nextMessages},
      unreadByContact: nextUnread,
      clearError: true,
    );

    if (isIncoming && selectedId == peerId) {
      _markRead(peerId);
    }
  }

  Future<void> _loadConversation(String contactId) async {
    try {
      final history = await repository.fetchConversation(contactId);
      state = state.copyWith(
        messagesByContact: {...state.messagesByContact, contactId: history},
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(error: 'Impossible de charger la conversation.');
    }
  }

  Future<void> _refreshRequests() async {
    final incomingFuture = repository.fetchIncomingRequests();
    final outgoingFuture = repository.fetchOutgoingRequests();
    final incoming = await incomingFuture;
    final outgoing = await outgoingFuture;

    final filteredResults = _filterSearchResults(
      state.searchResults,
      friends: state.friends,
      incomingRequests: incoming,
      outgoingRequests: outgoing,
    );

    state = state.copyWith(
      incomingRequests: incoming,
      outgoingRequests: outgoing,
      searchResults: filteredResults,
      clearError: true,
    );
  }

  List<ContactModel> _filterSearchResults(
    List<ContactModel> results, {
    required List<ContactModel> friends,
    required List<FriendRequestModel> incomingRequests,
    required List<FriendRequestModel> outgoingRequests,
  }) {
    final selfId = currentUserId;
    final excludedIds = <String>{
      ...friends.map((friend) => friend.id),
      ...incomingRequests.map((request) => request.user.id),
      ...outgoingRequests.map((request) => request.user.id),
      ...(selfId == null ? const <String>[] : <String>[selfId]),
    };

    return results.where((contact) => !excludedIds.contains(contact.id)).toList();
  }

  Future<void> _markRead(String contactId) async {
    final current = state.unreadByContact[contactId] ?? 0;
    if (current == 0) {
      return;
    }

    state = state.copyWith(
      unreadByContact: {...state.unreadByContact, contactId: 0},
    );

    try {
      await repository.markConversationRead(contactId);
    } catch (_) {
      // Keep local UX responsive even if network fails.
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    realtime.dispose();
    super.dispose();
  }
}

final contactsControllerProvider =
    StateNotifierProvider<ContactsController, ContactsState>((ref) {
      final api = ref.watch(apiClientProvider);
      final authState = ref.watch(authControllerProvider);

      final repository = ContactsRepository(api);
      final realtime = ContactsRealtimeService();

      return ContactsController(
        repository: repository,
        realtime: realtime,
        currentUserId: authState.user?.id,
      );
    });

final contactsUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(contactsControllerProvider).unreadTotal;
});
