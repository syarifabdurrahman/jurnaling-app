import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('JournalEntryData')
class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get mood => text().withDefault(Constant('neutral'))();
  TextColumn get imagePaths => text().nullable()(); // JSON array of image paths
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [JournalEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations step by step
        if (from == 1 && to >= 2) {
          // Version 1 -> 2: tried to add imagePath (unused, skip it)
        }
        if (from <= 2 && to >= 3) {
          // Version 2 -> 3: add imagePaths column
          // Check if column doesn't exist before adding
          try {
            await m.addColumn(journalEntries, journalEntries.imagePaths);
          } catch (e) {
            // Column might already exist, ignore error
          }
        }
        if (from <= 3 && to >= 4) {
          // Version 3 -> 4: ensure imagePaths column exists
          try {
            await m.addColumn(journalEntries, journalEntries.imagePaths);
          } catch (e) {
            // Column might already exist, ignore error
          }
        }
      },
    );
  }

  Future<List<JournalEntryData>> getAllEntries() {
    return (select(journalEntries)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  Future<JournalEntryData?> getEntryById(int id) {
    return (select(journalEntries)
          ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> createEntry(JournalEntriesCompanion entry) {
    return into(journalEntries).insert(entry);
  }

  Future<bool> updateEntry(JournalEntriesCompanion entry) {
    return (update(journalEntries)
          ..where((tbl) => tbl.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<bool> deleteEntry(int id) {
    return (update(journalEntries)
          ..where((tbl) => tbl.id.equals(id)))
        .write(JournalEntriesCompanion(deletedAt: Value(DateTime.now())))
        .then((rows) => rows > 0);
  }

  Future<Map<String, List<JournalEntryData>>> getEntriesGroupedByDate() async {
    final entries = await getAllEntries();
    final grouped = <String, List<JournalEntryData>>{};

    for (final entry in entries) {
      final dateKey = _formatDateKey(entry.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(entry);
    }

    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(entryDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    return '${entryDate.day}/${entryDate.month}/${entryDate.year}';
  }
}
