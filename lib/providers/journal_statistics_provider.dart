import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'journal_provider.dart';

/// Statistics data model
class JournalStatistics {
  const JournalStatistics({
    required this.totalEntries,
    required this.currentStreak,
    required this.longestStreak,
    required this.entriesThisWeek,
    required this.entriesThisMonth,
    required this.moodCounts,
    required this.recentMoods,
  });

  final int totalEntries;
  final int currentStreak;
  final int longestStreak;
  final int entriesThisWeek;
  final int entriesThisMonth;
  final Map<String, int> moodCounts;
  final List<String> recentMoods;

  JournalStatistics copyWith({
    int? totalEntries,
    int? currentStreak,
    int? longestStreak,
    int? entriesThisWeek,
    int? entriesThisMonth,
    Map<String, int>? moodCounts,
    List<String>? recentMoods,
  }) {
    return JournalStatistics(
      totalEntries: totalEntries ?? this.totalEntries,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      entriesThisWeek: entriesThisWeek ?? this.entriesThisWeek,
      entriesThisMonth: entriesThisMonth ?? this.entriesThisMonth,
      moodCounts: moodCounts ?? this.moodCounts,
      recentMoods: recentMoods ?? this.recentMoods,
    );
  }
}

/// Statistics provider
final journalStatisticsProvider = FutureProvider<JournalStatistics>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final entries = await db.getAllEntries();

  if (entries.isEmpty) {
    return const JournalStatistics(
      totalEntries: 0,
      currentStreak: 0,
      longestStreak: 0,
      entriesThisWeek: 0,
      entriesThisMonth: 0,
      moodCounts: {},
      recentMoods: [],
    );
  }

  // Sort entries by date (newest first)
  entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Calculate entries this week
  final weekAgo = today.subtract(const Duration(days: 7));
  final entriesThisWeek = entries.where((e) {
    final entryDate = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
    return entryDate.isAfter(weekAgo.subtract(const Duration(days: 1))) || entryDate.isAtSameMomentAs(weekAgo);
  }).length;

  // Calculate entries this month
  final monthAgo = DateTime(now.year, now.month - 1, now.day);
  final entriesThisMonth = entries.where((e) {
    final entryDate = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
    return entryDate.isAfter(monthAgo) || entryDate.isAtSameMomentAs(monthAgo);
  }).length;

  // Calculate current streak (consecutive days with entries)
  int currentStreak = 0;
  for (int i = 0; i < 365; i++) {
    final checkDate = today.subtract(Duration(days: i));
    final hasEntry = entries.any((e) {
      final entryDate = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      return entryDate.year == checkDate.year &&
             entryDate.month == checkDate.month &&
             entryDate.day == checkDate.day;
    });
    if (hasEntry) {
      currentStreak++;
    } else {
      break;
    }
  }

  // Calculate longest streak
  int longestStreak = 0;
  int tempStreak = 0;
  DateTime? lastDate;

  for (final entry in entries) {
    final entryDate = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);

    if (lastDate != null) {
      final diff = entryDate.difference(lastDate).inDays;
      if (diff == 1) {
        tempStreak++;
      } else if (diff > 1) {
        tempStreak = 1;
      }
    } else {
      tempStreak = 1;
    }

    longestStreak = longestStreak > tempStreak ? longestStreak : tempStreak;
    lastDate = entryDate;
  }

  // Count moods
  final moodCounts = <String, int>{};
  for (final entry in entries) {
    final mood = entry.mood.toLowerCase();
    moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
  }

  // Get recent moods (last 30 entries)
  final recentMoods = entries.take(30).map((e) => e.mood.toLowerCase()).toList();

  return JournalStatistics(
    totalEntries: entries.length,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    entriesThisWeek: entriesThisWeek,
    entriesThisMonth: entriesThisMonth,
    moodCounts: moodCounts,
    recentMoods: recentMoods,
  );
});

/// Entries grouped by date for calendar
final entriesByDateProvider = FutureProvider<Map<String, List<JournalEntryData>>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final entries = await db.getAllEntries();

  final grouped = <String, List<JournalEntryData>>{};
  for (final entry in entries) {
    final key = '${entry.createdAt.year}-${entry.createdAt.month}-${entry.createdAt.day}';
    grouped[key] = (grouped[key] ?? [])..add(entry);
  }

  return grouped;
});
