import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            if (context.mounted) {
              context.push(AppRoutes.matchLive);
            }
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
        context.push(AppRoutes.matchLive);
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
}
