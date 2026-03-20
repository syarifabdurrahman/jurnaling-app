import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../utils/responsive.dart';
import '../../providers/journal_provider.dart';
import '../../providers/journal_statistics_provider.dart';
import 'journal_editor_screen.dart';

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

/// Home screen - Daily mood check-in in card format
class JournalHomeScreen extends ConsumerStatefulWidget {
  const JournalHomeScreen({super.key});

  @override
  ConsumerState<JournalHomeScreen> createState() => _JournalHomeScreenState();
}

class _JournalHomeScreenState extends ConsumerState<JournalHomeScreen> {
  String? _todayMood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SwipeNavigator(
        currentRoute: '/home',
        onSwipeLeft: () => Navigator.of(context).pushReplacementNamed('/journal'),
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: context.bottomPadding + 100),
                      child: Column(
                        children: [
                          // Daily Journal Card
                          _buildDailyJournalCard(),
                          const SizedBox(height: 16),
                          // Insights Card
                          _buildInsightsCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Floating Nav Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: context.bottomPadding + 16,
              child: _buildFloatingNavPill(),
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
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          Text(
            '$greeting,',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textHighContrast,
              height: 1.2,
            ),
          ),
          Text(
            ' you',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: AppColors.textHighContrast,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavPill() {
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
                _buildNavItem(Icons.home_rounded, 'Home', true, () {}),
                const SizedBox(width: 4),
                _buildNavItem(Icons.book_rounded, 'Journal', false, () {
                  Navigator.of(context).pushReplacementNamed('/journal');
                }),
                const SizedBox(width: 4),
                _buildNavItem(Icons.insights_rounded, 'Insights', false, () {
                  Navigator.of(context).pushNamed('/insights');
                }),
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

  /// Daily Journal Card with mood check-in
  Widget _buildDailyJournalCard() {
    _hasEntryForToday(DateTime.now()); // Check entry for analytics
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentPrimary,
            AppColors.accentPrimary.withValues(alpha: 0.85),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Daily Journal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'How are you feeling today?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            // Mood icons row inside the card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMoodOption('Happy', Icons.sentiment_very_satisfied_rounded, AppColors.moodHappy),
                _buildMoodOption('Calm', Icons.sentiment_satisfied_rounded, AppColors.moodCalm),
                _buildMoodOption('Sad', Icons.sentiment_dissatisfied_rounded, AppColors.moodSad),
                _buildMoodOption('Anxious', Icons.sentiment_very_dissatisfied_rounded, AppColors.moodAnxious),
                _buildMoodOption('Neutral', Icons.sentiment_neutral_rounded, AppColors.moodNeutral),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Individual mood option button with icon
  Widget _buildMoodOption(String label, IconData icon, Color color) {
    final isSelected = _todayMood == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _todayMood = label;
          });
          // Navigate to editor to write journal with selected mood
          Future.delayed(const Duration(milliseconds: 200), () async {
            if (!mounted) return;
            // Import here to avoid circular dependency
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => JournalEditorScreen(initialMood: label),
              ),
            );
            // Refresh journal entries when returning from editor
            if (result == true && mounted) {
              ref.invalidate(journalEntriesProvider);
            }
          });
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isSelected ? color : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Insights Card
  Widget _buildInsightsCard() {
    final statsAsync = ref.watch(journalStatisticsProvider);

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/insights'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.secondarySoft, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.textHighContrast.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppColors.textHighContrast,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your Insights',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHighContrast,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              statsAsync.when(
                data: (stats) {
                  if (stats.moodCounts.isEmpty) {
                    return Text(
                      'Start journaling to see your mood patterns',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    );
                  }
                  return _buildMoodChart(stats.moodCounts, stats.totalEntries);
                },
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentPrimary),
                  ),
                ),
                error: (_, _) => Text(
                  'Track your mood patterns and view your journaling streaks.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mini mood chart for insights card
  Widget _buildMoodChart(Map<String, int> moodCounts, int totalEntries) {
    // Sort moods by count (highest first)
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week\'s Mood',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textHighContrast,
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal bar chart
        ...sortedMoods.take(3).map((entry) {
          final percentage = (entry.value / totalEntries * 100).clamp(0, 100);
          final color = _getMoodColor(entry.key);
          final moodName = _capitalizeFirst(entry.key);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          moodName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHighContrast,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${percentage.toInt()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / totalEntries,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

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

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  bool _hasEntryForToday(DateTime now) {
    // Check if there's an entry for today (simplified)
    // In a real app, you'd check with your provider
    return false;
  }
}
