import 'package:flutter_test/flutter_test.dart';
import 'package:neuronote/document_text_extractor.dart';

void main() {
  group('DocumentTextExtractor', () {
    test('rejects garbled PDF-like text', () {
      const garbage = '''
ADDITIONAL INFORMATION
B B A A A B B B
EDUCATION
BAAAAAABAAAAAAAAAAAAAABBA
PROFESSIONAL EXPERIENCE
B B C B F A BA B BF
''';
      expect(DocumentTextExtractor.isUsableContent(garbage), isFalse);
    });

    test('accepts normal study text', () {
      const text = '''
Photosynthesis is the process by which green plants convert light energy
into chemical energy. Chlorophyll absorbs sunlight and uses carbon dioxide
and water to produce glucose and oxygen for cellular respiration.
''';
      expect(DocumentTextExtractor.isUsableContent(text), isTrue);
    });

    test('prepareForAi truncates long content', () {
      final long = 'word ' * 2000;
      final prepared = DocumentTextExtractor.prepareForAi(long);
      expect(prepared.length, lessThanOrEqualTo(DocumentTextExtractor.maxAiChars + 20));
      expect(prepared.contains('[truncated]'), isTrue);
    });

    test('quiz source stays under limit', () {
      final long = 'biology topic ' * 500;
      final prepared = DocumentTextExtractor.prepareForAi(
        long,
        maxChars: DocumentTextExtractor.maxQuizSourceChars,
      );
      expect(
        prepared.length,
        lessThanOrEqualTo(DocumentTextExtractor.maxQuizSourceChars + 20),
      );
    });
  });
}
