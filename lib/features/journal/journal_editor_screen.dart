import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/colors.dart';
import '../../utils/responsive.dart';
import '../../providers/journal_provider.dart';
import '../../database/database.dart';
import 'widgets/mood_picker.dart';

/// Journal editor with organic warmth design
class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({
    super.key,
    this.entryId,
    this.initialMood,
  });

  final String? entryId;
  final String? initialMood;

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  late QuillController _quillController;
  MoodType? _selectedMood;
  final FocusNode _titleFocus = FocusNode();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _editorFocus = FocusNode();
  late final ScrollController _toolbarScrollController;
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];

  // Typography settings
  String _selectedFont = 'Plus Jakarta Sans';
  final double _fontSize = 16.0;

  // Current inline font size for new text
  String _currentSize = 'normal'; // 'small', 'normal', 'large', 'huge'

  // Current text color
  Color _currentColor = Colors.black;

  // Predefined colors for text color picker
  static const List<Color> _textColors = [
    Colors.black,
    Color(0xFF6B7280), // Gray
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _toolbarScrollController = ScrollController();
    _titleFocus.requestFocus();

    // Listen to selection changes to update toolbar
    _quillController.addListener(_onSelectionChanged);

    // Set initial mood if provided (only for new entries)
    if (widget.entryId == null && widget.initialMood != null) {
      _selectedMood = MoodType.values.firstWhere(
        (m) => m.name.toLowerCase() == widget.initialMood!.toLowerCase(),
        orElse: () => MoodType.neutral,
      );
    }

    // Load existing entry if editing
    if (widget.entryId != null) {
      _loadExistingEntry();
    }
  }

  void _onSelectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExistingEntry() async {
    try {
      final entryId = int.parse(widget.entryId!);
      final entry = await ref.read(journalEntryProvider(entryId).future);
      if (entry != null && mounted) {
        setState(() {
          _titleController.text = entry.title;

          // Load content
          try {
            final dynamic decoded = jsonDecode(entry.content);
            final document = Document.fromJson(decoded is List ? decoded : [decoded]);
            _quillController.document = document;
          } catch (e) {
            // Content parse error, keep empty document
          }

          // Load mood
          if (entry.mood.isNotEmpty) {
            _selectedMood = MoodType.values.firstWhere(
              (m) => m.name.toLowerCase() == entry.mood.toLowerCase(),
              orElse: () => MoodType.neutral,
            );
          }

          // Load images
          if (entry.imagePaths != null && entry.imagePaths!.isNotEmpty) {
            try {
              final paths = jsonDecode(entry.imagePaths!);
              if (paths is List) {
                _selectedImages.clear();
                _selectedImages.addAll(paths.cast<String>().map((p) => File(p)));
              }
            } catch (e) {
              // Image parse error
            }
          }
        });
      }
    } catch (e) {
      // Error loading entry, continue with empty state
    }
  }

  @override
  void dispose() {
    _quillController.removeListener(_onSelectionChanged);
    _quillController.dispose();
    _toolbarScrollController.dispose();
    _titleController.dispose();
    _titleFocus.dispose();
    _editorFocus.dispose();
    super.dispose();
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  bool get _hasContent {
    return _quillController.document.length != 0 ||
        _titleController.text.trim().isNotEmpty;
  }

  Future<void> _saveEntry() async {
    if (_titleController.text.trim().isEmpty) {
      _showTitleRequiredSnackBar();
      return;
    }

    final now = DateTime.now();
    final moodValue = _selectedMood?.name ?? 'neutral';
    final contentJson = _quillController.document.toDelta().toJson();

    // Extract image paths from Quill document
    final extractedImages = <String>[];
    for (var op in contentJson) {
      if (op.containsKey('insert')) {
        final insert = op['insert'];
        if (insert is Map && insert.containsKey('image')) {
          extractedImages.add(insert['image'] as String);
        }
      }
    }

    // Combine manually selected images with extracted images from Quill content
    final allImagePaths = {
      ..._selectedImages.map((f) => f.path),
      ...extractedImages,
    }.toList(); // Use Set to remove duplicates

    // Save image paths as JSON array
    final imagePathsJson = allImagePaths.isNotEmpty
        ? jsonEncode(allImagePaths)
        : null;

    try {
      if (widget.entryId != null) {
        // Update existing entry
        final entryId = int.parse(widget.entryId!);
        final entry = JournalEntriesCompanion(
          id: drift.Value(entryId),
          title: drift.Value(_titleController.text.trim()),
          content: drift.Value(jsonEncode(contentJson)),
          updatedAt: drift.Value(now),
          mood: drift.Value(moodValue),
          imagePaths: imagePathsJson != null ? drift.Value(imagePathsJson) : const drift.Value.absent(),
        );

        final success = await ref.read(journalOperationsProvider).updateEntry(entry);
        if (success && mounted) {
          _showSuccessSnackBar();
          Navigator.of(context).pop(true);
        } else if (mounted) {
          _showErrorSnackBar('Failed to update journal');
        }
      } else {
        // Create new entry
        final entry = JournalEntriesCompanion.insert(
          title: _titleController.text.trim(),
          content: jsonEncode(contentJson),
          createdAt: now,
          updatedAt: now,
          mood: drift.Value(moodValue),
          imagePaths: imagePathsJson != null ? drift.Value(imagePathsJson) : const drift.Value.absent(),
        );

        await ref.read(journalOperationsProvider).createEntry(entry);
        if (mounted) {
          _showSuccessSnackBar();
          Navigator.of(context).pop(true);
        }
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to save: $error');
      }
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Saved successfully',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.accentPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.moodAnxious,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showTitleRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Please add a title',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: AppColors.textHighContrast,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _discardChanges() {
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
              'Discard this journal?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textHighContrast,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your writing will be lost forever',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
                height: 1.5,
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
                            'Keep Editing',
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
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Text(
                            'Discard',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle background layering
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentPrimary.withValues(alpha: 0.06),
                    AppColors.accentPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ResponsivePadding(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: context.bottomPadding + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMoodPicker(context),
                          const SizedBox(height: 24),
                          _buildImageSection(context),
                          const SizedBox(height: 24),
                          _buildTitleField(context),
                          const SizedBox(height: 24),
                          _buildEditor(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondarySoft),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _hasContent ? _discardChanges : () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(16),
                child: const Icon(Icons.close_rounded, size: 22),
              ),
            ),
          ),
          const Spacer(),
          Text(
            widget.entryId == null ? 'New Journal' : 'Edit Journal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textHighContrast,
            ),
          ),
          const Spacer(),
          // Save button
          GestureDetector(
            onTap: _saveEntry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodPicker(BuildContext context) {
    return MoodPicker(
      selectedMood: _selectedMood,
      onMoodSelected: (mood) {
        setState(() {
          _selectedMood = mood;
        });
      },
    );
  }

  Widget _buildImageSection(BuildContext context) {
    // Only show images when they've been added via toolbar button
    if (_selectedImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image count header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.image_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} attached',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Selected images grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.secondarySoft),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.secondarySoft.withValues(alpha: 0.3),
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 32),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _removeImage(index),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.secondarySoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHighContrast.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocus,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textHighContrast,
          height: 1.3,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Give your journal a title...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        onSubmitted: (_) {
          _editorFocus.requestFocus();
        },
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.secondarySoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.textHighContrast.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _toolbarScrollController,
            child: Row(
              children: [
                _buildToolbarButton(
                  Icons.format_bold_rounded,
                  () => _toggleFormat(Attribute.bold),
                  isActive: _isFormatActive(Attribute.bold),
                ),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_italic_rounded,
                  () => _toggleFormat(Attribute.italic),
                  isActive: _isFormatActive(Attribute.italic),
                ),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_underlined_rounded,
                  () => _toggleFormat(Attribute.underline),
                  isActive: _isFormatActive(Attribute.underline),
                ),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_list_bulleted_rounded,
                  () => _toggleFormat(Attribute.ul),
                  isActive: _isFormatActive(Attribute.ul),
                ),
                const SizedBox(width: 8),
                // Font size buttons for inline sizing
                _buildSizeButton('S', () => _applySize('small')),
                const SizedBox(width: 4),
                _buildSizeButton('M', () => _clearSize()),
                const SizedBox(width: 4),
                _buildSizeButton('L', () => _applySize('large')),
                const SizedBox(width: 4),
                _buildSizeButton('XL', () => _applySize('huge')),
                const SizedBox(width: 8),
                _buildToolbarButton(Icons.text_fields_rounded, () {
                  _showTypographySettings(context);
                }),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_align_left_rounded,
                  () => _setAlignment(Attribute.leftAlignment),
                  isActive: _isAlignmentActive(Attribute.leftAlignment),
                ),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_align_center_rounded,
                  () => _setAlignment(Attribute.centerAlignment),
                  isActive: _isAlignmentActive(Attribute.centerAlignment),
                ),
                const SizedBox(width: 8),
                _buildToolbarButton(
                  Icons.format_align_right_rounded,
                  () => _setAlignment(Attribute.rightAlignment),
                  isActive: _isAlignmentActive(Attribute.rightAlignment),
                ),
                const SizedBox(width: 12),
                // Color picker button
                _buildColorButton(),
                const SizedBox(width: 8),
                // Image button
                _buildToolbarButton(
                  Icons.image_rounded,
                  () => _insertImage(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Editor
          Container(
            constraints: BoxConstraints(
              minHeight: context.screenHeight * 0.35,
            ),
            child: QuillEditor.basic(
              controller: _quillController,
              focusNode: _editorFocus,
              config: QuillEditorConfig(
                placeholder: 'Write your thoughts...',
                padding: EdgeInsets.zero,
                scrollable: true,
                customStyles: DefaultStyles(
                  paragraph: DefaultTextBlockStyle(
                    _getCurrentTextStyle(),
                    HorizontalSpacing.zero,
                    const VerticalSpacing(0, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                  // Add custom size styling
                  sizeSmall: _getCurrentTextStyle().copyWith(fontSize: 12),
                  sizeLarge: _getCurrentTextStyle().copyWith(fontSize: 20),
                  sizeHuge: _getCurrentTextStyle().copyWith(fontSize: 28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Selected images preview
          if (_selectedImages.isNotEmpty) ...[
            // Image preview header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.image_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedImages.length} image${_selectedImages.length > 1 ? 's' : ''} attached',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Image preview list
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final image = _selectedImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          image,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  void _showTypographySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Typography',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHighContrast,
                ),
              ),
              const SizedBox(height: 24),
              // Font Family
              Text(
                'Font Family',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildFontOption('Plus Jakarta Sans', setModalState),
                  _buildFontOption('Lora', setModalState),
                  _buildFontOption('Playfair Display', setModalState),
                ],
              ),
              const SizedBox(height: 24),
              // Note about inline sizes
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use S/M/L/XL buttons for inline font sizes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondarySoft.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'The quick brown fox jumps over the lazy dog',
                  style: _getSelectedFont(),
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
                              'Apply',
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
      ),
    );
  }

  Widget _buildFontOption(String fontName, StateSetter setModalState) {
    final isSelected = _selectedFont == fontName;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedFont = fontName;
        });
        setState(() {
          _selectedFont = fontName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPrimary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : AppColors.secondarySoft,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          fontName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.accentPrimary : AppColors.textHighContrast,
          ),
        ),
      ),
    );
  }

  TextStyle _getSelectedFont() {
    switch (_selectedFont) {
      case 'Lora':
        return GoogleFonts.lora(fontSize: _fontSize, color: AppColors.textHighContrast);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(fontSize: _fontSize, color: AppColors.textHighContrast);
      default:
        return GoogleFonts.plusJakartaSans(fontSize: _fontSize, color: AppColors.textHighContrast);
    }
  }

  Widget _buildToolbarButton(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accentPrimary
            : AppColors.secondarySoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: AppColors.accentPrimary, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? Colors.white : AppColors.textHighContrast,
          ),
        ),
      ),
    );
  }

  // Build font size button
  Widget _buildSizeButton(String label, VoidCallback onTap) {
    // Each button has a unique size value
    final sizeValue = _getSizeValue(label);
    // Only active if current size matches this button's value
    final isActive = _currentSize == sizeValue;

    return Container(
      key: ValueKey('size_$label'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: label == 'S' ? 10 : label == 'M' ? 12 : label == 'L' ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Get size value attribute string for Quill
  String _getSizeValue(String label) {
    switch (label) {
      case 'S': return 'small';
      case 'L': return 'large';
      case 'XL': return 'huge';
      case 'M': return 'normal';
      default: return 'normal';
    }
  }

  // Apply inline font size to selected text and set for new text
  void _applySize(String size) {
    // Store current size for new text
    setState(() {
      _currentSize = size;
    });

    // Apply format at current position (works for selection and cursor)
    final sizeAttr = Attribute(Attribute.size.key, AttributeScope.inline, size);
    _quillController.formatSelection(sizeAttr);

    // Move focus back to editor
    _editorFocus.requestFocus();
  }

  // Clear size from selected text (back to default)
  void _clearSize() {
    // Set to normal (default) size
    setState(() {
      _currentSize = 'normal';
    });

    // Remove size attribute at current position
    final sizeAttr = Attribute(Attribute.size.key, AttributeScope.inline, null);
    _quillController.formatSelection(sizeAttr);

    // Move focus back to editor
    _editorFocus.requestFocus();
  }

  // Check if a format attribute is active at current selection
  bool _isFormatActive(Attribute attribute) {
    final style = _quillController.getSelectionStyle();
    return style.attributes.containsKey(attribute.key);
  }

  // Check if an alignment attribute is active
  bool _isAlignmentActive(Attribute attribute) {
    final style = _quillController.getSelectionStyle();
    // Get the alignment attribute from the style (all alignments use same key)
    for (final attr in style.attributes.values) {
      if (attr.key == Attribute.leftAlignment.key) {
        // Compare the actual alignment value
        return attr.value == attribute.value;
      }
    }
    return false;
  }

  // Toggle a format attribute
  void _toggleFormat(Attribute attribute) {
    if (_isFormatActive(attribute)) {
      _quillController.formatSelection(Attribute.clone(attribute, null));
    } else {
      _quillController.formatSelection(attribute);
    }
    // Refresh UI to show updated active state
    setState(() {});
  }

  // Set text alignment
  void _setAlignment(Attribute alignment) {
    _quillController.formatSelection(alignment);
    // Refresh UI to show updated active state
    setState(() {});
  }

  // Apply text color
  void _applyColor(Color color) {
    setState(() {
      _currentColor = color;
    });
    // Convert color to hex format for Quill
    final colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final colorAttr = Attribute(Attribute.color.key, AttributeScope.inline, colorHex);
    _quillController.formatSelection(colorAttr);
    _editorFocus.requestFocus();
  }

  // Show color picker
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Text Color', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 280,
          height: 120,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _textColors.length,
            itemBuilder: (context, index) {
              final color = _textColors[index];
              final isSelected = _currentColor == color;
              return GestureDetector(
                onTap: () {
                  _applyColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.accentPrimary : Colors.grey.shade300,
                      width: isSelected ? 3 : 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }

  // Build color button showing current color
  Widget _buildColorButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.secondarySoft.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showColorPicker(),
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Insert image at cursor position
  Future<void> _insertImage() async {
    final List<XFile> images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        for (var image in images) {
          _selectedImages.add(File(image.path));
        }
      });

      // Focus back to editor to continue writing
      _editorFocus.requestFocus();
    }
  }

  TextStyle _getCurrentTextStyle() {
    switch (_selectedFont) {
      case 'Lora':
        return GoogleFonts.lora(fontSize: _fontSize, color: AppColors.textHighContrast);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(fontSize: _fontSize, color: AppColors.textHighContrast);
      default:
        return GoogleFonts.plusJakartaSans(fontSize: _fontSize, color: AppColors.textHighContrast);
    }
  }

}

/// Mood types for journal entries
enum MoodType {
  happy,
  calm,
  sad,
  anxious,
  neutral,
}

/// Extension for mood display properties
extension MoodTypeExtension on MoodType {
  IconData get icon {
    switch (this) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied_rounded;
      case MoodType.calm:
        return Icons.sentiment_satisfied_rounded;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied_rounded;
      case MoodType.anxious:
        return Icons.sentiment_very_dissatisfied_rounded;
      case MoodType.neutral:
        return Icons.sentiment_neutral_rounded;
    }
  }

  String get emoji {
    switch (this) {
      case MoodType.happy:
        return '😊';
      case MoodType.calm:
        return '😌';
      case MoodType.sad:
        return '😢';
      case MoodType.anxious:
        return '😰';
      case MoodType.neutral:
        return '😐';
    }
  }

  String get label {
    switch (this) {
      case MoodType.happy:
        return 'Happy';
      case MoodType.calm:
        return 'Calm';
      case MoodType.sad:
        return 'Sad';
      case MoodType.anxious:
        return 'Anxious';
      case MoodType.neutral:
        return 'Neutral';
    }
  }

  Color get color {
    switch (this) {
      case MoodType.happy:
        return AppColors.moodHappy;
      case MoodType.calm:
        return AppColors.moodCalm;
      case MoodType.sad:
        return AppColors.moodSad;
      case MoodType.anxious:
        return AppColors.moodAnxious;
      case MoodType.neutral:
        return AppColors.moodNeutral;
    }
  }
}
