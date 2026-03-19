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
  });

  final String? entryId;

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
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _toolbarScrollController = ScrollController();
    _titleFocus.requestFocus();

    // Listen to selection changes to update toolbar
    _quillController.addListener(_onSelectionChanged);

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

  Future<void> _pickImage() async {
    final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((xFile) => File(xFile.path)));
      });
    }
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

    // Save image paths as JSON array
    final imagePathsJson = _selectedImages.isNotEmpty
        ? jsonEncode(_selectedImages.map((f) => f.path).toList())
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
          // Floating save button
          Positioned(
            right: 24,
            bottom: context.bottomPadding + 24,
            child: _buildSaveButton(context),
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
                onTap: () {
                  // TODO: Show options
                },
                borderRadius: BorderRadius.circular(16),
                child: const Icon(Icons.more_horiz_rounded, size: 22),
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
    // Always show upload button and selected images
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Upload button
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondarySoft,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textHighContrast.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    color: AppColors.accentPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Select Photos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHighContrast,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedImages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedImages.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Selected images grid
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                ),
              ),
            ),
          ),
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
              // Font Size
              Text(
                'Font Size: ${_fontSize.toInt()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Slider(
                value: _fontSize,
                min: 12,
                max: 24,
                divisions: 12,
                activeColor: AppColors.accentPrimary,
                onChanged: (value) {
                  setModalState(() {
                    _fontSize = value;
                  });
                  setState(() {
                    _fontSize = value;
                  });
                },
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

  // Check if a format attribute is active at current selection
  bool _isFormatActive(Attribute attribute) {
    final style = _quillController.getSelectionStyle();
    return style.attributes.containsKey(attribute.key);
  }

  // Check if an alignment attribute is active
  bool _isAlignmentActive(Attribute attribute) {
    final style = _quillController.getSelectionStyle();
    return style.attributes.containsKey(attribute.key);
  }

  // Toggle a format attribute
  void _toggleFormat(Attribute attribute) {
    if (_isFormatActive(attribute)) {
      _quillController.formatText(
        _quillController.selection.start,
        _quillController.selection.end - _quillController.selection.start,
        Attribute.clone(attribute, null),
      );
    } else {
      _quillController.formatText(
        _quillController.selection.start,
        _quillController.selection.end - _quillController.selection.start,
        attribute,
      );
    }
    // Refresh UI to show updated active state
    setState(() {});
  }

  // Set text alignment
  void _setAlignment(Attribute alignment) {
    _quillController.formatText(
      _quillController.selection.start,
      _quillController.selection.end - _quillController.selection.start,
      alignment,
    );
    // Refresh UI to show updated active state
    setState(() {});
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

  Widget _buildSaveButton(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saveEntry,
          borderRadius: BorderRadius.circular(28),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20),
              Icon(Icons.check_rounded, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
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
