import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';

/// Database provider
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'mindflow.db'));
  return AppDatabase(NativeDatabase(file));
});

/// Journal entries provider - provides all non-deleted entries as a Future
final journalEntriesProvider = FutureProvider<List<JournalEntryData>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getAllEntries();
});

/// Journal entries grouped by date provider
final journalEntriesGroupedProvider = FutureProvider<Map<String, List<JournalEntryData>>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getEntriesGroupedByDate();
});

/// Single journal entry provider
final journalEntryProvider = FutureProvider.family<JournalEntryData?, int>((ref, id) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getEntryById(id);
});

/// Journal operations state
class JournalOperations {
  const JournalOperations({
    required this.createEntry,
    required this.updateEntry,
    required this.deleteEntry,
  });

  final Future<int> Function(JournalEntriesCompanion entry) createEntry;
  final Future<bool> Function(JournalEntriesCompanion entry) updateEntry;
  final Future<bool> Function(int id) deleteEntry;
}

/// Journal operations provider
final journalOperationsProvider = Provider<JournalOperations>((ref) {
  final db = ref.watch(databaseProvider);
  return db.when(
    data: (database) {
      return JournalOperations(
        createEntry: (entry) => database.createEntry(entry),
        updateEntry: (entry) => database.updateEntry(entry),
        deleteEntry: (id) => database.deleteEntry(id),
      );
    },
    loading: () => throw UnimplementedError('Database not initialized'),
    error: (e, _) => throw UnimplementedError('Database error: $e'),
  );
});
