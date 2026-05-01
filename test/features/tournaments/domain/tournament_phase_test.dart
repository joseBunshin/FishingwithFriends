import 'package:fishing_with_friends/features/tournaments/domain/tournament_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final starts = DateTime.utc(2026, 4, 12, 10);
  final ends = DateTime.utc(2026, 4, 12, 18);

  group('phaseFor', () {
    test('now < starts → registration', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: false,
          now: DateTime.utc(2026, 4, 12, 9),
        ),
        TournamentPhase.registration,
      );
    });

    test('now == starts (boundary) → live', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: false,
          now: starts,
        ),
        TournamentPhase.live,
      );
    });

    test('starts < now < ends → live', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: false,
          now: DateTime.utc(2026, 4, 12, 14),
        ),
        TournamentPhase.live,
      );
    });

    test('now == ends (boundary) → live', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: false,
          now: ends,
        ),
        TournamentPhase.live,
      );
    });

    test('now > ends → closed', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: false,
          now: DateTime.utc(2026, 4, 12, 19),
        ),
        TournamentPhase.closed,
      );
    });

    test('isClosed=true overrides to closed even when now < starts', () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: true,
          now: DateTime.utc(2026, 4, 12, 9),
        ),
        TournamentPhase.closed,
      );
    });

    test('isClosed=true overrides to closed even when now is inside window',
        () {
      expect(
        phaseFor(
          startsAt: starts,
          endsAt: ends,
          isClosed: true,
          now: DateTime.utc(2026, 4, 12, 14),
        ),
        TournamentPhase.closed,
      );
    });
  });
}
