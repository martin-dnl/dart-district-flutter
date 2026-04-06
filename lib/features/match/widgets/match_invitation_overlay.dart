import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_routes.dart';
import '../controller/match_controller.dart';
import '../controller/ongoing_matches_controller.dart';
import '../controller/pending_invitation_controller.dart';
import '../models/match_model.dart';
import 'match_invitation_modal.dart';
import 'match_refused_modal.dart';
import 'match_waiting_response_modal.dart';

class MatchInvitationOverlay extends ConsumerWidget {
  const MatchInvitationOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingInvitation = ref.watch(pendingInvitationProvider);
    final ongoingMatches = ref.watch(ongoingMatchesControllerProvider);

    final invitationResponse = ongoingMatches.lastInvitationResponse;
    if (invitationResponse != null && pendingInvitation.match != null) {
      final sameInvitation =
          invitationResponse.id == pendingInvitation.match!.id;
      if (sameInvitation && pendingInvitation.isWaiting) {
        if (invitationResponse.invitationStatus == InvitationStatus.accepted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(pendingInvitationProvider.notifier).clearInvitation();
            ref
                .read(matchControllerProvider.notifier)
                .loadMatch(invitationResponse);
            ref
                .read(ongoingMatchesControllerProvider.notifier)
                .clearLastInvitationResponse();
            ref.read(routerProvider).push(_routeForMatch(invitationResponse));
          });
        } else if (invitationResponse.invitationStatus ==
            InvitationStatus.refused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(pendingInvitationProvider.notifier)
                .respondToInvitation(InvitationStatus.refused);
            ref
                .read(ongoingMatchesControllerProvider.notifier)
                .clearLastInvitationResponse();
          });
        }
      }
    }

    return Stack(
      children: [
        child,
        // Show received invitation modal
        if (ongoingMatches.pendingInvitations.isNotEmpty)
          GestureDetector(
            onTap: () {}, // Prevent interaction with background
            child: _buildReceivedInvitationModal(
              context,
              ref,
              ongoingMatches.pendingInvitations.first,
            ),
          ),
        // Show waiting response modal
        if (pendingInvitation.isWaiting && pendingInvitation.match != null)
          GestureDetector(
            onTap: () {}, // Prevent interaction with background
            child: _buildWaitingModal(context, ref, pendingInvitation.match!),
          ),
        // Show refused modal
        if (pendingInvitation.responseStatus == InvitationStatus.refused &&
            pendingInvitation.match != null)
          GestureDetector(
            onTap: () {}, // Prevent interaction with background
            child: _buildRefusedModal(context, ref, pendingInvitation.match!),
          ),
      ],
    );
  }

  Widget _buildReceivedInvitationModal(
    BuildContext context,
    WidgetRef ref,
    MatchModel invitation,
  ) {
    return MatchInvitationModal(
      invitation: invitation,
      onAccept: () async {
        final acceptedMatch = await ref
            .read(ongoingMatchesControllerProvider.notifier)
            .acceptInvitation(invitation.id);
        if (acceptedMatch == null || !context.mounted) {
          return;
        }

        ref.read(matchControllerProvider.notifier).loadMatch(acceptedMatch);
        ref.read(routerProvider).push(_routeForMatch(acceptedMatch));
      },
      onRefuse: () async {
        await ref
            .read(ongoingMatchesControllerProvider.notifier)
            .refuseInvitation(invitation.id);
      },
    );
  }

  Widget _buildWaitingModal(
    BuildContext context,
    WidgetRef ref,
    MatchModel invitation,
  ) {
    return MatchWaitingResponseModal(
      opponentName: invitation.players[1].name,
      onCancel: () async {
        await ref
            .read(ongoingMatchesControllerProvider.notifier)
            .cancelOutgoingInvitation(invitation.id);
        ref.read(pendingInvitationProvider.notifier).clearInvitation();
      },
    );
  }

  Widget _buildRefusedModal(
    BuildContext context,
    WidgetRef ref,
    MatchModel invitation,
  ) {
    return MatchRefusedModal(
      opponentName: invitation.players[1].name,
      onDismiss: () {
        ref.read(pendingInvitationProvider.notifier).clearInvitation();
      },
    );
  }

  String _routeForMatch(MatchModel match) {
    final mode = match.mode.trim().toLowerCase();
    if (mode == 'cricket') {
      return AppRoutes.matchCricket;
    }
    if (mode == 'chasseur') {
      return _hasChasseurZonesSelected(match)
          ? AppRoutes.matchChasseur
          : AppRoutes.matchChasseurZones;
    }
    return AppRoutes.matchLive;
  }

  bool _hasChasseurZonesSelected(MatchModel match) {
    final picked = <int>{};
    for (final round in match.roundHistory) {
      final label = round.dartPositions.isNotEmpty
          ? (round.dartPositions.first.label ?? '')
          : '';
      final selection = RegExp(r'^Z:([1-9]|1[0-9]|20|25)$').firstMatch(label);
      if (selection != null) {
        picked.add(round.playerIndex);
      }
    }
    return picked.length >= 2;
  }
}
