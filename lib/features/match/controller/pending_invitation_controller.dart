import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_model.dart';

class PendingInvitationState {
  const PendingInvitationState({
    this.match,
    this.isWaiting = false,
    this.responseStatus,
    this.error,
  });

  final MatchModel? match;
  final bool isWaiting;
  final InvitationStatus? responseStatus; // pending, accepted, refused
  final String? error;

  PendingInvitationState copyWith({
    MatchModel? match,
    bool? isWaiting,
    InvitationStatus? responseStatus,
    String? error,
    bool clearMatch = false,
  }) {
    return PendingInvitationState(
      match: clearMatch ? null : (match ?? this.match),
      isWaiting: isWaiting ?? this.isWaiting,
      responseStatus: responseStatus ?? this.responseStatus,
      error: error ?? this.error,
    );
  }
}

class PendingInvitationController
    extends StateNotifier<PendingInvitationState> {
  PendingInvitationController() : super(const PendingInvitationState());

  void startWaiting(MatchModel invitation) {
    state = state.copyWith(
      match: invitation,
      isWaiting: true,
      responseStatus: InvitationStatus.pending,
    );
  }

  void respondToInvitation(InvitationStatus status) {
    state = state.copyWith(responseStatus: status, isWaiting: false);
  }

  void clearInvitation() {
    state = const PendingInvitationState();
  }
}

final pendingInvitationProvider =
    StateNotifierProvider<PendingInvitationController, PendingInvitationState>(
      (ref) => PendingInvitationController(),
    );
