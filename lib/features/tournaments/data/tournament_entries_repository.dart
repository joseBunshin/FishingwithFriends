import 'package:fishing_with_friends/core/error/app_exception.dart';
import 'package:fishing_with_friends/features/catches/domain/catch.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entries_data_source.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_entry_dto.dart';
import 'package:fishing_with_friends/features/tournaments/data/tournament_side_pot_dto.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_entry.dart';
import 'package:fishing_with_friends/features/tournaments/domain/tournament_side_pot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentEntriesRepository {
  TournamentEntriesRepository({required this.dataSource});

  final TournamentEntriesDataSource dataSource;

  /// Submit an existing catch as a tournament entry.
  /// Snapshots the relevant catch fields onto the entry row so non-friend
  /// tournament fellows can read the leaderboard without seeing the raw
  /// `catches` row.
  Future<TournamentEntry> submitEntry({
    required String tournamentId,
    required Catch source,
    required String anglerId,
  }) async {
    if (anglerId.isEmpty) {
      throw const AuthFailure('Sign in to submit an entry.');
    }
    if (source.anglerId != anglerId) {
      throw const ValidationFailure('You can only submit your own catches.');
    }
    try {
      final row = TournamentEntryDto.toInsertRow(
        tournamentId: tournamentId,
        catchId: source.id,
        anglerId: anglerId,
        speciesLabel: source.speciesLabel,
        weightKg: source.weightKg,
        lengthCm: source.lengthCm,
        photoPath: source.photoPaths.isEmpty ? null : source.photoPaths.first,
        caughtAt: source.caughtAt,
      );
      final inserted = await dataSource.insertEntry(row);
      return TournamentEntryDto.fromRow(inserted);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ValidationFailure(
          "You've already submitted this catch to this tournament.",
        );
      }
      throw NetworkFailure('Submit failed: ${e.message}', cause: e);
    }
  }

  Future<TournamentEntry> approve({
    required String entryId,
    required String creatorId,
  }) async => _setStatus(entryId, 'approved', creatorId);

  Future<TournamentEntry> reject({
    required String entryId,
    required String creatorId,
  }) async => _setStatus(entryId, 'rejected', creatorId);

  Future<List<TournamentEntry>> listForTournament(String tournamentId) async {
    try {
      final rows = await dataSource.selectForTournament(tournamentId);
      return rows.map(TournamentEntryDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load entries: ${e.message}', cause: e);
    }
  }

  Future<List<TournamentSidePot>> listSidePots(String tournamentId) async {
    try {
      final rows = await dataSource.selectSidePots(tournamentId);
      return rows.map(TournamentSidePotDto.fromRow).toList(growable: false);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to load side pots: ${e.message}',
          cause: e);
    }
  }

  Future<TournamentSidePot> addSidePot({
    required String tournamentId,
    required String name,
    required TournamentMetric metric,
    String? speciesFilter,
  }) async {
    try {
      final inserted = await dataSource.insertSidePot(
        TournamentSidePotDto.toInsertRow(
          tournamentId: tournamentId,
          name: name,
          metric: metric,
          speciesFilter: speciesFilter,
        ),
      );
      return TournamentSidePotDto.fromRow(inserted);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Failed to add side pot: ${e.message}', cause: e);
    }
  }

  Future<TournamentEntry> _setStatus(
    String entryId,
    String status,
    String approvedBy,
  ) async {
    try {
      final updated = await dataSource.updateStatus(
        entryId: entryId,
        status: status,
        approvedBy: approvedBy,
      );
      return TournamentEntryDto.fromRow(updated);
    } on PostgrestException catch (e) {
      throw NetworkFailure('Could not update entry: ${e.message}', cause: e);
    }
  }
}
