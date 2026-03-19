import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/database.dart';

/// Page size for lazy loading
const int _pageSize = 10;

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

/// Paginated journal entries state
class PaginatedEntriesState {
  const PaginatedEntriesState({
    required this.entries,
    required this.hasReachedMax,
    this.isLoading = false,
  });

  final List<JournalEntryData> entries;
  final bool hasReachedMax;
  final bool isLoading;

  PaginatedEntriesState copyWith({
    List<JournalEntryData>? entries,
    bool? hasReachedMax,
    bool? isLoading,
  }) {
    return PaginatedEntriesState(
      entries: entries ?? this.entries,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Paginated journal entries notifier
class PaginatedEntriesNotifier extends StateNotifier<PaginatedEntriesState> {
  PaginatedEntriesNotifier(this._database) : super(const PaginatedEntriesState(entries: [], hasReachedMax: false, isLoading: false)) {
    if (_database != null) {
      loadInitial();
    }
  }

  /// Constructor for loading state (when database is not ready)
  PaginatedEntriesNotifier.loading() : _database = null, super(const PaginatedEntriesState(entries: [], hasReachedMax: false, isLoading: true));

  /// Updates the database reference and loads initial data
  void updateDatabase(AppDatabase database) {
    // Create a new notifier with the actual database
    // This will be called when transitioning from loading to ready
  }

  final AppDatabase? _database;
  int _currentPage = 0;

  Future<void> loadInitial() async {
    if (_database == null) return;

    _currentPage = 0;
    state = const PaginatedEntriesState(entries: [], hasReachedMax: false, isLoading: true);
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_database == null || state.isLoading || state.hasReachedMax) return;

    state = state.copyWith(isLoading: true);

    try {
      final allEntries = await _database.getAllEntries();
      final startIndex = _currentPage * _pageSize;
      final endIndex = startIndex + _pageSize;

      if (startIndex >= allEntries.length) {
        state = state.copyWith(hasReachedMax: true, isLoading: false);
        return;
      }

      final newEntries = allEntries.sublist(
        startIndex,
        endIndex > allEntries.length ? allEntries.length : endIndex,
      );

      state = state.copyWith(
        entries: [...state.entries, ...newEntries],
        hasReachedMax: endIndex >= allEntries.length,
        isLoading: false,
      );

      _currentPage++;
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

/// Paginated journal entries provider - handles loading state
final paginatedEntriesProvider = StateNotifierProvider<PaginatedEntriesNotifier, PaginatedEntriesState>((ref) {
  final db = ref.watch(databaseProvider);

  // Watch the database and create notifier when ready
  return db.when(
    data: (database) => PaginatedEntriesNotifier(database),
    loading: () => PaginatedEntriesNotifier.loading(),
    error: (e, _) => PaginatedEntriesNotifier.loading(),
  );
});
