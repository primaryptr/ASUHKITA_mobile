





import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/gemini_service.dart';

void main() {
  final gemini = GeminiService();

  group('FR-49 | GeminiService.generateLetter (Fallback Mode)', () {
    test('Mengembalikan string tidak kosong untuk nama dan topik valid', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Bintang',
        topic: 'semangat belajar untuk ujian',
      );
      expect(result.isNotEmpty, isTrue,
          reason: 'generateLetter harus mengembalikan teks (fallback atau Gemini)');
    });

    test('Surat mengandung nama alias anak', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Langit',
        topic: 'dukungan cita-cita',
      );
      expect(result.contains('Langit'), isTrue,
          reason: 'Fallback letter harus menyebut nama alias anak');
    });

    test('Surat selalu diakhiri tanda tangan orang tua asuh', () async {
      final result = await gemini.generateLetter(
        childAlias: 'Rizki',
        topic: 'prestasi akademik',
      );
      expect(result.toLowerCase().contains('orang tua asuh'), isTrue,
          reason: 'Surat harus mengandung tanda tangan standar');
    });
  });

  group('FR-50 | GeminiService.summarizeReport (Fallback Mode)', () {
    test('Mengembalikan ringkasan tidak kosong', () async {
      const rawReport =
          'Selama semester ganjil, Bintang menunjukkan peningkatan signifikan pada pelajaran IPA dengan nilai 90.';
      final result = await gemini.summarizeReport(rawReport);
      expect(result.isNotEmpty, isTrue);
    });

    test('Ringkasan fallback mengandung kata "Ringkasan"', () async {
      final result = await gemini.summarizeReport('Laporan singkat anak asuh.');
      expect(
        result.toLowerCase().contains('ringkasan') || result.contains('-'),
        isTrue,
        reason: 'Fallback summary harus terformat sebagai poin ringkasan',
      );
    });

    test('Teks kosong tidak menyebabkan crash', () async {
      final result = await gemini.summarizeReport('');
      expect(result.isNotEmpty, isTrue);
    });
  });

  group('polishReportStory (Fallback Mode)', () {
    test('merapikan kalimat narasi tanpa menambah judul Ringkasan atau bullet', () async {
      final polished = await gemini.polishReportStory(
        childName: 'Bintang',
        category: 'Prestasi',
        rawStory: 'hari ini bintang menang lomba mewarnai dia sangat gembira',
      );
      expect(polished.isNotEmpty, isTrue);
      expect(polished.contains('Ringkasan Perkembangan Anak'), isFalse);
      expect(polished.contains('•'), isFalse);
      expect(polished.startsWith('Hari ini'), isTrue);
      expect(polished.endsWith('.'), isTrue);
    });

    test('membersihkan awalan bullet dan header ringkasan jika ada', () async {
      final polished = await gemini.polishReportStory(
        childName: 'Awan',
        category: 'Kegiatan',
        rawStory: 'Ringkasan Perkembangan Anak:\n• awan belajar matematika bersama teman',
      );
      expect(polished.contains('Ringkasan Perkembangan Anak'), isFalse);
      expect(polished.contains('•'), isFalse);
      expect(polished, equals('Awan belajar matematika bersama teman.'));
    });

    test('FAQ tidak lagi mempromosikan Kotak Amal IoT', () async {
      final faq = await gemini.askFaq('Apa itu AsuhKita?');
      expect(faq.toLowerCase().contains('kotak amal'), isFalse);
    });
  });

  group('FR-51 | GeminiService.askFaq (Fallback Mode)', () {
    test('Mengembalikan jawaban tidak kosong', () async {
      final result = await gemini.askFaq('Bagaimana cara berdonasi?');
      expect(result.isNotEmpty, isTrue);
    });

    test('Jawaban fallback mengandung nama "AsuhKita"', () async {
      final result = await gemini.askFaq('Apa itu AsuhKita?');
      expect(result.toLowerCase().contains('asuhkita'), isTrue,
          reason: 'Fallback FAQ harus menyebut nama aplikasi');
    });

    test('FAQ dengan riwayat chat tidak crash', () async {
      final history = [
        {'role': 'user', 'text': 'Halo'},
        {'role': 'model', 'text': 'Halo juga! Ada yang bisa saya bantu?'},
      ];
      final result = await gemini.askFaq('Berapa nominal donasi minimum?',
          history: history);
      expect(result.isNotEmpty, isTrue);
    });

    test('Pertanyaan kosong tidak menyebabkan crash', () async {

      final result = await gemini.askFaq('');
      expect(result, isA<String>());
    });
  });
}
