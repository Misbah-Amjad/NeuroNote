import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocumentTextExtractor {
  /// Keep under Groq on-demand TPM (~12k tokens). ~4 chars/token → ~4000 chars safe.
  static const int maxAiChars = 4000;
  static const int maxQuizSourceChars = 2200;

  static Future<String> extract(
    String fileName,
    Uint8List bytes,
  ) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    switch (ext) {
      case 'txt':
      case 'md':
        return _cleanExtractedText(_decodeText(bytes));
      case 'pdf':
        return _cleanExtractedText(_extractPdfText(bytes));
      case 'docx':
        return _cleanExtractedText(_extractDocxText(bytes));
      default:
        return _cleanExtractedText(_decodeText(bytes));
    }
  }

  static String prepareForAi(String content, {int maxChars = maxAiChars}) {
    final cleaned = _cleanExtractedText(content);
    if (cleaned.length <= maxChars) return cleaned;
    return '${cleaned.substring(0, maxChars)}... [truncated]';
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  static String _extractPdfText(Uint8List bytes) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();
      for (var i = 0; i < document.pages.count; i++) {
        final pageText = extractor
            .extractText(startPageIndex: i, endPageIndex: i)
            .trim();
        if (pageText.isNotEmpty) {
          buffer.writeln(pageText);
        }
      }
      final text = buffer.toString().trim();
      if (text.length > 80 && !_isGarbageText(text)) return text;

      final fullText = extractor.extractText().trim();
      if (fullText.length > 80 && !_isGarbageText(fullText)) return fullText;
    } catch (_) {
    } finally {
      document?.dispose();
    }
    return '';
  }

  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final doc = archive.findFile('word/document.xml');
      if (doc == null) return '';
      final xml = utf8.decode(doc.content as List<int>);
      final text = xml
          .replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t')
          .replaceAll(RegExp(r'</w:p>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return text;
    } catch (_) {
      return '';
    }
  }

  static String _cleanExtractedText(String text) {
    return text
        .replaceAll(RegExp(r'\x00'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static bool _isGarbageText(String text) {
    if (text.trim().length < 40) return true;

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;

    final shortWords = words.where((w) => w.length <= 2).length;
    if (shortWords / words.length > 0.45) return true;

    final singleCharWords = words.where((w) => w.length == 1).length;
    if (words.length >= 8 && singleCharWords / words.length > 0.22) return true;

    final repeatedCharWords = words.where((w) {
      if (w.length < 4) return false;
      return w.toLowerCase().split('').toSet().length <= 3;
    }).length;
    if (words.length >= 6 && repeatedCharWords / words.length > 0.18) {
      return true;
    }

    final lettersOnly = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.length < 40) return true;

    final uniqueLetters = lettersOnly.toLowerCase().split('').toSet().length;
    if (uniqueLetters < 10 && lettersOnly.length > 80) return true;

    final letterCounts = <String, int>{};
    for (final ch in lettersOnly.toLowerCase().split('')) {
      letterCounts[ch] = (letterCounts[ch] ?? 0) + 1;
    }
    final maxCount = letterCounts.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxCount / lettersOnly.length > 0.35) return true;

    return false;
  }

  static bool isUsableContent(String? content) {
    if (content == null || content.trim().isEmpty) return false;
    final lower = content.toLowerCase();
    if (lower.startsWith('file uploaded:')) return false;
    if (lower.contains('(binary file)')) return false;
    if (lower.contains('could not read file')) return false;
    if (lower.contains('could not extract')) return false;
    if (content.trim().length < 40) return false;
    if (_isGarbageText(content)) return false;
    return true;
  }
}
