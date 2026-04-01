import 'package:flutter_test/flutter_test.dart';

import 'package:dart_district/features/tournaments/data/tournament_service.dart';
import 'package:dart_district/features/tournaments/models/bracket_match_model.dart';
import 'package:dart_district/features/tournaments/models/pool_model.dart';
import 'package:dart_district/features/tournaments/models/tournament_model.dart';

void main() {
  group('TournamentModel.fromApi', () {
    test('marks user as registered when current user is in players', () {
      final model = TournamentModel.fromApi(
        {
          'id': 't1',
          'name': 'Open 501',
          'players': [
            {'user_id': 'u-1'},
            {'user_id': 'u-2'},
          ],
          'scheduled_at': '2026-01-10T10:00:00.000Z',
        },
        currentUserId: 'u-2',
      );

      expect(model.id, 't1');
      expect(model.name, 'Open 501');
      expect(model.isRegistered, isTrue);
      expect(model.scheduledAt.toUtc().year, 2026);
    });

    test('applies safe defaults for missing values', () {
      final model = TournamentModel.fromApi(
        {'id': 't2'},
        currentUserId: 'unknown',
      );

      expect(model.name, 'Tournoi');
      expect(model.mode, '501');
      expect(model.finish, 'double_out');
      expect(model.format, 'single_elimination');
      expect(model.maxPlayers, 16);
      expect(model.enrolledPlayers, 0);
      expect(model.currentPhase, 'registration');
      expect(model.status, 'open');
      expect(model.isRegistered, isFalse);
    });
  });

  group('Pool models', () {
    test('computes legDifference in standings entry', () {
      final entry = PoolStandingEntry.fromApi({
        'user_id': 'u1',
        'matches_played': 3,
        'matches_won': 2,
        'legs_won': 11,
        'legs_lost': 7,
        'points': 6,
        'user': {'username': 'Alice'},
      });

      expect(entry.username, 'Alice');
      expect(entry.legDifference, 4);
    });

    test('creates PoolModel with players and injected standings', () {
      final standings = [
        PoolStandingEntry.fromApi({
          'user_id': 'u1',
          'matches_played': 1,
          'matches_won': 1,
          'legs_won': 3,
          'legs_lost': 0,
          'points': 3,
          'user': {'username': 'Alice'},
        }),
      ];

      final model = PoolModel.fromApi(
        {
          'id': 'p1',
          'tournament_id': 't1',
          'pool_name': 'A',
          'players': [
            {
              'user_id': 'u1',
              'seed': 1,
              'is_qualified': true,
              'user': {'username': 'Alice'},
            },
          ],
        },
        standings,
      );

      expect(model.id, 'p1');
      expect(model.poolName, 'A');
      expect(model.players, hasLength(1));
      expect(model.players.first.username, 'Alice');
      expect(model.players.first.isQualified, isTrue);
      expect(model.standings, hasLength(1));
    });
  });

  group('BracketMatchModel.fromApi', () {
    test('parses players and completed status', () {
      final model = BracketMatchModel.fromApi({
        'id': 'b1',
        'tournament_id': 't1',
        'round_number': 2,
        'position': 1,
        'status': 'completed',
        'player1_id': 'u1',
        'player2_id': 'u2',
        'winner_id': 'u2',
        'player1': {'username': 'Alice'},
        'player2': {'username': 'Bob'},
      });

      expect(model.roundNumber, 2);
      expect(model.player1Name, 'Alice');
      expect(model.player2Name, 'Bob');
      expect(model.isCompleted, isTrue);
      expect(model.isInProgress, isFalse);
    });

    test('defaults to pending status when absent', () {
      final model = BracketMatchModel.fromApi({'id': 'b2'});

      expect(model.status, 'pending');
      expect(model.isCompleted, isFalse);
      expect(model.isInProgress, isFalse);
    });
  });

  group('TournamentPlayerModel.fromApi', () {
    test('parses seed, elo and qualification flags', () {
      final player = TournamentPlayerModel.fromApi({
        'user_id': 'u1',
        'seed': 3,
        'is_qualified': true,
        'is_disqualified': false,
        'user': {
          'username': 'Alice',
          'avatar_url': 'https://img.test/a.png',
          'elo': 1425,
        },
      });

      expect(player.userId, 'u1');
      expect(player.username, 'Alice');
      expect(player.avatarUrl, 'https://img.test/a.png');
      expect(player.elo, 1425);
      expect(player.seed, 3);
      expect(player.isQualified, isTrue);
      expect(player.isDisqualified, isFalse);
    });
  });
}
