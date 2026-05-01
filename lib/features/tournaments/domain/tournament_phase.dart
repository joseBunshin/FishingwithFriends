/// Derived client-side phase of a tournament. The DB only stores
/// starts_at / ends_at / is_closed; this enum is computed at render time.
enum TournamentPhase { registration, live, closed }

/// Pure phase-derivation function for tests + view-model use.
/// Boundaries: now == starts_at → live; now == ends_at → live;
/// is_closed=true overrides to closed regardless of dates.
TournamentPhase phaseFor({
  required DateTime startsAt,
  required DateTime endsAt,
  required bool isClosed,
  required DateTime now,
}) {
  if (isClosed) return TournamentPhase.closed;
  if (now.isBefore(startsAt)) return TournamentPhase.registration;
  if (now.isAfter(endsAt)) return TournamentPhase.closed;
  return TournamentPhase.live;
}
