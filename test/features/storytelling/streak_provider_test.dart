import 'package:fishing_with_friends/features/storytelling/application/streak_provider.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _day(int year, int month, int day) => DateTime(year, month, day);

void main() {
  test('empty days returns Streak.empty', () {
    final s = computeStreakFromDays(<DateTime>{}, _day(2026, 4, 10));
    expect(s.current, 0);
    expect(s.longest, 0);
  });

  test('single fishing day today gives current=1, longest=1', () {
    final s = computeStreakFromDays(
      {_day(2026, 4, 10)},
      _day(2026, 4, 10),
    );
    expect(s.current, 1);
    expect(s.longest, 1);
  });

  test('three consecutive days ending today gives current=3, longest=3', () {
    final s = computeStreakFromDays(
      {_day(2026, 4, 8), _day(2026, 4, 9), _day(2026, 4, 10)},
      _day(2026, 4, 10),
    );
    expect(s.current, 3);
    expect(s.longest, 3);
  });

  test('most recent fishing day was 2 days ago resets current to 0', () {
    final s = computeStreakFromDays(
      {_day(2026, 4, 6), _day(2026, 4, 7), _day(2026, 4, 8)},
      _day(2026, 4, 10),
    );
    expect(s.current, 0);
    expect(s.longest, 3);
  });

  test('soft reset: most recent day was yesterday — streak still alive',
      () {
    final s = computeStreakFromDays(
      {_day(2026, 4, 8), _day(2026, 4, 9)},
      _day(2026, 4, 10),
    );
    expect(s.current, 2);
    expect(s.longest, 2);
  });

  test('two non-overlapping streaks of 4 and 7 — longest=7', () {
    final s = computeStreakFromDays(
      {
        // 4-day streak
        _day(2026, 1, 1),
        _day(2026, 1, 2),
        _day(2026, 1, 3),
        _day(2026, 1, 4),
        // 7-day streak ending 2026-04-10
        _day(2026, 4, 4),
        _day(2026, 4, 5),
        _day(2026, 4, 6),
        _day(2026, 4, 7),
        _day(2026, 4, 8),
        _day(2026, 4, 9),
        _day(2026, 4, 10),
      },
      _day(2026, 4, 10),
    );
    expect(s.current, 7);
    expect(s.longest, 7);
  });

  test('a single isolated day has longest=1', () {
    final s = computeStreakFromDays(
      {_day(2026, 1, 5), _day(2026, 4, 1)},
      _day(2026, 4, 10),
    );
    expect(s.longest, 1);
    expect(s.current, 0);
  });
}
