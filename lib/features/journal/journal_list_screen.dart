import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../utils/responsive.dart';
import '../../providers/journal_provider.dart';
import '../../database/database.dart';
import 'journal_editor_screen.dart';
import 'journal_detail_screen.dart';

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

/// Journal list screen with search and card layout
class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      ref.read(paginatedEntriesProvider.notifier).loadMore();
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SwipeNavigator(
        currentRoute: '/journal',
        onSwipeLeft: () => Navigator.of(context).pushReplacementNamed('/insights'),
        onSwipeRight: () => Navigator.of(context).pushReplacementNamed('/home'),
        child: Stack(
          children: [
            // Background
            _buildBackground(),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  // Search bar
                  _buildSearchBar(),
                  Expanded(
                    child: entriesAsync.when(
                      data: (entries) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            child: entries.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      ref.invalidate(journalEntriesProvider);
                                    },
                                    color: AppColors.accentPrimary,
                                    backgroundColor: Colors.white,
                                    child: _buildJournalGrid(entries),
                                  ),
                          ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.accentPrimary),
                      ),
                      error: (error, _) => _buildErrorState(error),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            'Your Journal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textHighContrast,
            ),
          ),
          const Spacer(),
          // Add button in header instead of FAB
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.of(context).pushNamed('/editor');
                  // Auto-refresh the list when returning from editor
                  if (result == true && mounted) {
                    ref.invalidate(journalEntriesProvider);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondarySoft, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.textHighContrast.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 12),
              child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textHighContrast,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search your journal...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textMuted,
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
                _buildNavItem(Icons.book_rounded, 'Journal', true, () {}),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No entries yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textHighContrast,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first journal entry',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ],
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
            'Something went wrong',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textHighContrast,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalGrid(List<JournalEntryData> entries) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: context.bottomPadding + 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildJournalCard(entries[index], index == 0);
      },
    );
  }

  Widget _buildJournalCard(JournalEntryData entry, bool isFirst) {
    final previewText = _getPreviewText(entry.content);
    final moodIcon = _getMoodIcon(entry.mood);

    // Parse image paths from JSON
    List<String> imagePaths = [];
    if (entry.imagePaths != null && entry.imagePaths!.isNotEmpty) {
      try {
        final decoded = jsonDecode(entry.imagePaths!);
        if (decoded is List) {
          imagePaths = decoded.cast<String>();
        }
      } catch (e) {
        // Handle legacy single path
        imagePaths = [entry.imagePaths!];
      }
    }
    final hasImages = imagePaths.isNotEmpty;

    return GestureDetector(
      onTap: () => _showDetailScreen(entry),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isFirst
              ? const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                )
              : BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: AppColors.textHighContrast.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleDateCard(entry.createdAt),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with title, mood icon, and action buttons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHighContrast,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.secondarySoft.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            moodIcon,
                            size: 18,
                            color: AppColors.textHighContrast,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          Icons.edit_rounded,
                          AppColors.accentPrimary,
                          () => _editEntry(entry),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          Icons.delete_rounded,
                          AppColors.moodAnxious,
                          () => _deleteEntry(entry),
                        ),
                      ],
                    ),
                  // Image preview
                  if (hasImages) ...[
                    const SizedBox(height: 12),
                    // Display images in a grid
                    if (imagePaths.length == 1)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(imagePaths.first),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 800, // Optimize for thumbnail
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: AppColors.secondarySoft.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      color: AppColors.textMuted,
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: imagePaths.length > 6 ? 6 : imagePaths.length,
                        itemBuilder: (context, imgIndex) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(imagePaths[imgIndex]),
                                  fit: BoxFit.cover,
                                  cacheWidth: 400, // Optimize for grid thumbnail
                                  gaplessPlayback: true, // Smooth loading
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.secondarySoft.withValues(alpha: 0.3),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: AppColors.textMuted,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Show "more" indicator if there are additional images
                                if (imgIndex == 5 && imagePaths.length > 6)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    child: Center(
                                      child: Text(
                                        '+${imagePaths.length - 6}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    // Show count if more than 6 images
                    if (imagePaths.length > 6) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${imagePaths.length} photos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                  // Quote preview
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w200,
                            color: AppColors.accentPrimary,
                            height: 1.0,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            previewText.isNotEmpty ? previewText : 'Your thoughts will appear here...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              fontStyle: FontStyle.italic,
                              color: previewText.isNotEmpty
                                  ? AppColors.textHighContrast
                                  : AppColors.textMuted,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '"',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w200,
                            color: AppColors.accentPrimary,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showDetailScreen(JournalEntryData entry) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => JournalDetailScreen(entry: entry),
      ),
    );

    // Handle edit or delete from detail screen
    if (result != null && mounted) {
      if (result == 'edit') {
        await _editEntry(entry);
      } else if (result == 'delete') {
        _deleteEntry(entry);
      }
    }
  }

  /// Simplified date card - just month and day
  Widget _buildSimpleDateCard(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final month = months[date.month - 1];
    final day = date.day.toString();

    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            month,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.accentPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEntry(JournalEntryData entry) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(entryId: entry.id.toString()),
      ),
    );
    // Refresh the list if the entry was saved
    if (result == true && mounted) {
      ref.invalidate(journalEntriesProvider);
    }
  }

  void _deleteEntry(JournalEntryData entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              'Delete this journal?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textHighContrast,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.secondarySoft),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHighContrast,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.moodAnxious,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(context).pop();
                          // Delete the entry
                          await ref.read(journalOperationsProvider).deleteEntry(entry.id);
                          // Refresh the list
                          ref.invalidate(journalEntriesProvider);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Text(
                            'Delete',
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
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

  String _getPreviewText(String contentJson) {
    try {
      final dynamic decoded = jsonDecode(contentJson);
      final document = Document.fromJson(decoded is List ? decoded : [decoded]);
      final text = document.toPlainText().trim();
      if (text.length > 150) {
        return '${text.substring(0, 150)}...';
      }
      return text;
    } catch (e) {
      return '';
    }
  }
}
