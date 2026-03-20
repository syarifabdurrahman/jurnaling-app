import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../utils/responsive.dart';
import '../../providers/journal_statistics_provider.dart';
import '../../database/database.dart';

/// Swipe navigation widget for smooth screen transitions
class SwipeNavigator extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final String currentRoute;

  const SwipeNavigator({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('swipe_$currentRoute'),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // Swipe right (negative velocity, finger moving right) -> go to next screen
        if (velocity < -500 && onSwipeLeft != null) {
          onSwipeLeft!();
        }
        // Swipe left (positive velocity, finger moving left) -> go to previous screen
        else if (velocity > 500 && onSwipeRight != null) {
          onSwipeRight!();
        }
      },
      child: child,
    );
  }
}

/// Insights screen - Streaks, Stats, and Calendar
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(journalStatisticsProvider);
    final entriesByDateAsync = ref.watch(entriesByDateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SwipeNavigator(
        currentRoute: '/insights',
        onSwipeRight: () => Navigator.of(context).pushReplacementNamed('/journal'),
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: context.bottomPadding + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    statsAsync.when(
                      data: (stats) => Column(
                        children: [
                          _buildStreakCard(stats),
                          const SizedBox(height: 16),
                          _buildStatsCards(stats),
                          const SizedBox(height: 24),
                          _buildMoodDistribution(stats.moodCounts),
                          const SizedBox(height: 24),
                          _buildCalendar(entriesByDateAsync),
                        ],
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.accentPrimary),
                      ),
                      error: (error, _) => _buildErrorState(error),
                    ),
                  ],
                ),
              ),
            ),
            // Floating Nav Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: context.bottomPadding + 16,
              child: _buildFloatingNavPill(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.surface,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Your Insights',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textHighContrast,
      ),
    );
  }

  Widget _buildStreakCard(JournalStatistics stats) {
    final days = stats.currentStreak;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentPrimary,
            AppColors.accentPrimary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days == 1 ? 'Day' : 'Days',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$days',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'streak!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (stats.longestStreak > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Best: ${stats.longestStreak} days',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(JournalStatistics stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Entries',
            '${stats.totalEntries}',
            Icons.book_rounded,
            AppColors.accentPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Week',
            '${stats.entriesThisWeek}',
            Icons.calendar_today_rounded,
            AppColors.accentSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'This Month',
            '${stats.entriesThisMonth}',
            Icons.calendar_month_rounded,
            AppColors.moodCalm,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHighContrast.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textHighContrast,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodDistribution(Map<String, int> moodCounts) {
    if (moodCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by count
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = moodCounts.values.reduce((a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHighContrast.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mood Distribution',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textHighContrast,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedMoods.map((entry) {
            final percentage = (entry.value / total * 100).toInt();
            final color = _getMoodColor(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getMoodIcon(entry.key),
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _capitalizeFirst(entry.key),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHighContrast,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percentage%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: entry.value / total,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCalendar(AsyncValue<Map<String, List<JournalEntryData>>> entriesByDateAsync) {
    return entriesByDateAsync.when(
      data: (entriesByDate) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.textHighContrast.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Journal Calendar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHighContrast,
                ),
              ),
              const SizedBox(height: 16),
              _buildCalendarGrid(entriesByDate),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accentPrimary),
      ),
      error: (error, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCalendarGrid(Map<String, List<JournalEntryData>> entriesByDate) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final startingWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_getMonthName(now.month)} ${now.year}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHighContrast,
                ),
              ),
            ],
          ),
        ),
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                day,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...List.generate(6, (weekIndex) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final dayNumber = weekIndex * 7 + dayIndex - startingWeekday + 1;

              if (weekIndex == 0 && dayIndex < startingWeekday) {
                return const SizedBox(width: 40, height: 40);
              }

              if (dayNumber > daysInMonth) {
                return const SizedBox(width: 40, height: 40);
              }

              final dateKey = '${now.year}-${now.month}-$dayNumber';
              final hasEntry = entriesByDate.containsKey(dateKey);
              final isToday = dayNumber == now.day;

              return GestureDetector(
                onTap: () => _showDateEntries(context, dateKey, entriesByDate),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: hasEntry
                        ? AppColors.accentPrimary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(color: AppColors.accentPrimary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: hasEntry ? FontWeight.w700 : FontWeight.w500,
                        color: hasEntry ? AppColors.accentPrimary : AppColors.textHighContrast,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  void _showDateEntries(BuildContext context, String dateKey, Map<String, List<JournalEntryData>> entriesByDate) {
    final entries = entriesByDate[dateKey];
    if (entries == null || entries.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.secondarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _formatDateKey(dateKey),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textHighContrast,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(entries.length, (index) {
              final entry = entries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHighContrast,
                  ),
                ),
                subtitle: Text(
                  _capitalizeFirst(entry.mood),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                trailing: Icon(
                  _getMoodIcon(entry.mood),
                  color: _getMoodColor(entry.mood),
                  size: 20,
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: Text(
                      'Close',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavPill(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.textHighContrast,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.textHighContrast.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', false, () {
                  Navigator.of(context).pushReplacementNamed('/home');
                }),
                const SizedBox(width: 4),
                _buildNavItem(Icons.book_rounded, 'Journal', false, () {
                  Navigator.of(context).pushReplacementNamed('/journal');
                }),
                const SizedBox(width: 4),
                _buildNavItem(Icons.insights_rounded, 'Insights', true, () {}),
                const SizedBox(width: 4),
                _buildNavItem(Icons.person_rounded, 'Profile', false, () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.textMuted.withValues(alpha: 0.7),
              size: 20,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.moodAnxious,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load insights',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHighContrast,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getMoodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy': return Icons.sentiment_very_satisfied_rounded;
      case 'calm': return Icons.sentiment_satisfied_rounded;
      case 'sad': return Icons.sentiment_dissatisfied_rounded;
      case 'anxious': return Icons.sentiment_very_dissatisfied_rounded;
      default: return Icons.sentiment_neutral_rounded;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy': return AppColors.moodHappy;
      case 'calm': return AppColors.moodCalm;
      case 'sad': return AppColors.moodSad;
      case 'anxious': return AppColors.moodAnxious;
      default: return AppColors.moodNeutral;
    }
  }

  String _getMonthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDateKey(String dateKey) {
    final parts = dateKey.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return '${_getMonthName(month)} $day, $year';
  }
}
