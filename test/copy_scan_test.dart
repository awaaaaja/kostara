import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// TP-REC-04 / AC-REC-04: teks UI feed — tanpa klaim probabilitistik
/// ("probabilitas", "kemungkinan", "akurasi%") dan format skor wajib
/// "Skor kecocokan NN/100". Scan string literal pada lib/ (baris komentar
/// dikesampingkan — negasi internal di doc comment bukan copy produk).
void main() {
  final libDir = Directory('lib');
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('scan menemukan sumber UI', () {
    expect(files, isNotEmpty);
  });

  test('tanpa copy klaim probabilitas/akurasi di string UI', () {
    final forbidden = ['probabilitas', 'kemungkinan', 'akurasi'];
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue; // komentar: bukan copy produk
        final lower = line.toLowerCase();
        for (final w in forbidden) {
          if (lower.contains(w)) {
            hits.add('${f.path}:${i + 1}: $line');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: 'copy feed dilarang klaim metrik: $hits');
  });

  test('format skor feed: "Skor kecocokan NN/100" (AC-REC-04)', () {
    final feed = File(
      'lib/features/discovery/home_feed_screen.dart',
    ).readAsStringSync();
    expect(feed, contains('Skor kecocokan'));
    expect(
      RegExp(r'Skor kecocokan \$\{item\.score\}/100').hasMatch(feed),
      isTrue,
      reason: 'skor tampil sebagai NN/100, bukan persen palsu',
    );
    // jangan ada format lama 'Kecocokan …%' pada kartu feed
    expect(RegExp(r"Kecocokan \$\{[^}]+\}%").hasMatch(feed), isFalse);
  });
}
