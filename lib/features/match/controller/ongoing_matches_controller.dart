import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_providers.dart';
import '../../auth/controller/auth_controller.dart';
import '../data/match_realtime_service.dart';
import '../data/match_service.dart';
import '../models/match_model.dart';

class OngoingMatchesState {
  const OngoingMatchesState({
    this.matches = const [],
    this.pendingInvitations = const [],
    this.lastInvitationResponse,
    this.isLoading = false,
    this.error,
  });

  final List<MatchModel> matches;
  final List<MatchModel> pendingInvitations;
  final MatchModel? lastInvitationResponse;
  final bool isLoading;
  final String? error;

  OngoingMatchesState copyWith({
    List<MatchModel>? matches,
    List<MatchModel>? pendingInvitations,
    MatchModel? lastInvitationResponse,
    bool clearLastInvitationResponse = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OngoingMatchesState(
      matches: matches ?? this.matches,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      lastInvitationResponse: clearLastInvitationResponse
          ? null
          : (lastInvitationResponse ?? this.lastInvitationResponse),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OngoingMatchesController extends StateNotifier<OngoingMatchesState> {
  OngoingMatchesController({
    required this.service,
    required this.realtime,
    required this.currentUserId,
  }) : super(const OngoingMatchesState()) {
    if (currentUserId != null && currentUserId!.isNotEmpty) {
      _bootstrap();
      realtime.connect(userId: currentUserId!);
      _invitationSub = realtime.invitationStream.listen(_onInvitationReceived);
      _scoreUpdateSub = realtime.scoreUpdateStream.listen(_onScoreUpdate);
    }
  }

  final MatchService service;
  final MatchRealtimeService realtime;
  final String? currentUserId;

  StreamSubscription<MatchModel>? _invitationSub;
  StreamSubscription<MatchModel>? _scoreUpdateSub;

  Future<void> _bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final matches = await service.getOngoingMatches();
      final pendingInvitations = matches
          .where((m) => m.invitationStatus == InvitationStatus.pending)
          .toList();
      final activeMatches = matches
          .where((m) => m.status == MatchStatus.inProgress)
          .toList();

      state = state.copyWith(
        matches: activeMatches,
        pendingInvitations: pendingInvitations,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Impossible de charger les matchs en cours.',
      );
    }
  }

  void _onInvitationReceived(MatchModel invitation) {
    if (invitation.invitationStatus == InvitationStatus.pending) {
      final updated = [...state.pendingInvitations, invitation];
      state = state.copyWith(pendingInvitations: updated);
    }
  }

  void _onScoreUpdate(MatchModel updatedMatch) {
    // Update ongoing match or invitation status
    final matchIndex = state.matches.indexWhere((m) => m.id == updatedMatch.id);
    if (matchIndex >= 0) {
      final updated = [...state.matches];
      updated[matchIndex] = updatedMatch;
      state = state.copyWith(matches: updated);
    }

    final invIndex = state.pendingInvitations.indexWhere(
      (m) => m.id == updatedMatch.id,
    );
    if (invIndex >= 0) {
      final updated = [...state.pendingInvitations];
      if (updatedMatch.invitationStatus == InvitationStatus.accepted) {
        updated.removeAt(invIndex);
        state = state.copyWith(
          pendingInvitations: updated,
          matches: [...state.matches, updatedMatch],
          lastInvitationResponse: updatedMatch,
        );
      } else if (updatedMatch.invitationStatus == InvitationStatus.refused) {
        updated.removeAt(invIndex);
        state = state.copyWith(
          pendingInvitations: updated,
          lastInvitationResponse: updatedMatch,
        );
      }
      return;
    }

    if (updatedMatch.inviterId == currentUserId &&
        updatedMatch.invitationStatus != null) {
      final alreadyTracked = state.matches.any((m) => m.id == updatedMatch.id);
      state = state.copyWith(
        matches:
            updatedMatch.invitationStatus == InvitationStatus.accepted &&
                !alreadyTracked
            ? [...state.matches, updatedMatch]
            : state.matches,
        lastInvitationResponse: updatedMatch,
      );
    }
  }

  Future<MatchModel?> acceptInvitation(String matchId) async {
    try {
      final match = await service.acceptInvitation(matchId);
      final updated = [
        ...state.pendingInvitations.where((m) => m.id != matchId),
      ];
      state = state.copyWith(
        pendingInvitations: updated,
        matches: [...state.matches, match],
        clearError: true,
      );
      return match;
    } catch (e) {
      state = state.copyWith(error: 'Impossible d\'accepter l\'invitation.');
      return null;
    }
  }

  Future<void> refuseInvitation(String matchId) async {
    try {
      await service.refuseInvitation(matchId);
      final updated = [
        ...state.pendingInvitations.where((m) => m.id != matchId),
      ];
      state = state.copyWith(pendingInvitations: updated, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Impossible de refuser l\'invitation.');
    }
  }

  Future<void> cancelOutgoingInvitation(String matchId) async {
    try {
      await service.cancelMatch(matchId);
      state = state.copyWith(clearError: true);
    } catch (_) {
      state = state.copyWith(error: 'Impossible d\'annuler l\'invitation.');
    }
  }

  void clearLastInvitationResponse() {
    state = state.copyWith(clearLastInvitationResponse: true);
  }

  @override
  void dispose() {
    _invitationSub?.cancel();
    _scoreUpdateSub?.cancel();
    realtime.dispose();
    super.dispose();
  }
}

final ongoingMatchesControllerProvider =
    StateNotifierProvider<OngoingMatchesController, OngoingMatchesState>((ref) {
      final api = ref.watch(apiClientProvider);
      final authState = ref.watch(authControllerProvider);

      final service = MatchService(api);
      final realtime = MatchRealtimeService();

      return OngoingMatchesController(
        service: service,
        realtime: realtime,
        currentUserId: authState.user?.id,
      );
    });
