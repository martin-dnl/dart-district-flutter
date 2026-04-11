import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/match/models/match_model.dart';

class InvitationNotificationAction {
  const InvitationNotificationAction({
    required this.matchId,
    required this.actionId,
  });

  final String matchId;
  final String actionId;
}

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<InvitationNotificationAction> _actionController =
      StreamController<InvitationNotificationAction>.broadcast();
  final Set<String> _displayedInvitationIds = <String>{};
  bool _initialized = false;

  Stream<InvitationNotificationAction> get invitationActions =>
      _actionController.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'match_invitation_actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'accept_invite',
              'Accepter',
            ),
            DarwinNotificationAction.plain(
              'decline_invite',
              'Refuser',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    _initialized = true;
  }

  Future<void> showMatchInvitation(MatchModel invitation) async {
    if (!_initialized) {
      await initialize();
    }

    if (_displayedInvitationIds.contains(invitation.id)) {
      return;
    }
    _displayedInvitationIds.add(invitation.id);

    final opponent = invitation.players.length > 1
        ? invitation.players[1].name
        : 'Joueur';

    final payload = jsonEncode(<String, dynamic>{'matchId': invitation.id});

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'match_invites',
        'Invitations de match',
        channelDescription: 'Notifications pour accepter une invitation de match',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('accept_invite', 'Accepter'),
          AndroidNotificationAction('decline_invite', 'Refuser'),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'match_invitation_actions',
      ),
    );

    await _plugin.show(
      invitation.id.hashCode,
      'Invitation de match',
      '$opponent vous invite a jouer',
      details,
      payload: payload,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _dispatchAction(response.actionId ?? '', response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    LocalNotificationService.instance._dispatchAction(
      response.actionId ?? '',
      response.payload,
    );
  }

  void _dispatchAction(String actionId, String? payload) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final matchId = (decoded['matchId'] ?? '').toString();
      if (matchId.isEmpty) {
        return;
      }
      _actionController.add(
        InvitationNotificationAction(matchId: matchId, actionId: actionId),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Notification payload decode failed: $error');
      }
    }
  }
}
