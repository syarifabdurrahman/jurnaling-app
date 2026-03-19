import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../database/database.dart';

/// Journal detail screen - shows full journal entry
class JournalDetailScreen extends StatelessWidget {
  const JournalDetailScreen({
    super.key,
    required this.entry,
  });

  final JournalEntryData entry;

  @override
  Widget build(BuildContext context) {
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
        imagePaths = [entry.imagePaths!];
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textHighContrast),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textHighContrast),
            onPressed: () {
              Navigator.of(context).pop('edit');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: AppColors.moodAnxious),
            onPressed: () {
              Navigator.of(context).pop('delete');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and mood
            Row(
              children: [
                _buildDateCard(entry.createdAt),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(moodIcon, size: 24, color: AppColors.textHighContrast),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              entry.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textHighContrast,
              ),
            ),
            const SizedBox(height: 24),
            // Images
            if (imagePaths.isNotEmpty) ...[
              ...List.generate(imagePaths.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(imagePaths[index]),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],
            // Content
            QuillEditor.basic(
              controller: QuillController(
                document: Document.fromJson(_parseContent(entry.content)),
                selection: const TextSelection.collapsed(offset: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final month = months[date.month - 1];
    final day = date.day.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accentPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.accentPrimary,
            ),
          ),
        ],
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

  List<dynamic> _parseContent(String contentJson) {
    try {
      final dynamic decoded = jsonDecode(contentJson);
      return decoded is List ? decoded : [decoded];
    } catch (e) {
      return [];
    }
  }
}
