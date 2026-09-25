import 'package:flutter_test/flutter_test.dart';
import 'package:kostara/core/util/payment_schedule.dart';

void main() {
  group('effectivePaymentStatus (AC-PAY-02)', () {
    final due = DateTime(2026, 10, 17);
    test('unpaid lewat tanggal → overdue', () {
      expect(
        effectivePaymentStatus('unpaid', due, DateTime(2026, 10, 18)),
        'overdue',
      );
    });
    test('unpaid tepat hari-H → belum overdue', () {
      expect(
        effectivePaymentStatus('unpaid', due, DateTime(2026, 10, 17)),
        'unpaid',
      );
    });
    test('unpaid sebelum tanggal → unpaid', () {
      expect(
        effectivePaymentStatus('unpaid', due, DateTime(2026, 10, 16)),
        'unpaid',
      );
    });
    test('paid tetap paid walau lewat tanggal', () {
      expect(effectivePaymentStatus('paid', due, DateTime(2027, 1, 1)), 'paid');
    });
    test('waktu jam tidak memicu overdue lebih awal', () {
      expect(
        effectivePaymentStatus('unpaid', due, DateTime(2026, 10, 17, 23, 59)),
        'unpaid',
      );
    });
  });

  group('label & dueIn', () {
    test('paymentStatusLabel', () {
      expect(paymentStatusLabel('paid'), 'Lunas');
      expect(paymentStatusLabel('overdue'), 'Terlambat');
      expect(paymentStatusLabel('unpaid'), 'Belum dibayar');
    });
    test('dueInLabel hari ini / N hari / lewat', () {
      expect(
        dueInLabel(DateTime(2026, 10, 17), DateTime(2026, 10, 17)),
        'Jatuh tempo hari ini',
      );
      expect(
        dueInLabel(DateTime(2026, 10, 23), DateTime(2026, 10, 17)),
        'Jatuh tempo dalam 6 hari',
      );
      expect(
        dueInLabel(DateTime(2026, 10, 15), DateTime(2026, 10, 17)),
        'Lewat 2 hari dari jatuh tempo',
      );
    });
    test('parseDateOnly khusus date-only (kontrak kolom due_date)', () {
      expect(parseDateOnly('2026-10-01'), DateTime(2026, 10, 1));
      expect(parseDateOnly('2028-02-29'), DateTime(2028, 2, 29));
      expect(parseDateOnly(null), isA<DateTime>());
      expect(parseDateOnly('bukan-tanggal'), isA<DateTime>());
    });
  });

  group('reminderFireUtc (AC-PAY-03, Asia/Jakarta = UTC+7)', () {
    test('09:00 WIB = 02:00 UTC pada hari-H−offset', () {
      final fire = reminderFireUtc(DateTime(2026, 10, 17), 7);
      expect(fire, DateTime.utc(2026, 10, 10, 2));
      expect(
        reminderFireUtc(DateTime(2026, 10, 17), 0),
        DateTime.utc(2026, 10, 17, 2),
      );
      expect(
        reminderFireUtc(DateTime(2026, 10, 17), 3),
        DateTime.utc(2026, 10, 14, 2),
      );
      expect(
        reminderFireUtc(DateTime(2026, 10, 17), 1),
        DateTime.utc(2026, 10, 16, 2),
      );
    });
    test('lintas bulan & tahun kabisat', () {
      expect(
        reminderFireUtc(DateTime(2026, 3, 1), 7),
        DateTime.utc(2026, 2, 22, 2),
      );
      expect(
        reminderFireUtc(DateTime(2028, 3, 1), 1),
        DateTime.utc(2028, 2, 29, 2),
      );
      expect(
        reminderFireUtc(DateTime(2027, 3, 1), 1),
        DateTime.utc(2027, 2, 28, 2),
      );
    });
    test('id notifikasi deterministik, 31-bit, beda offset beda id', () {
      final a = reminderNotificationId('t1', DateTime(2026, 10, 17), 7);
      final b = reminderNotificationId('t1', DateTime(2026, 10, 17), 7);
      final c = reminderNotificationId('t1', DateTime(2026, 10, 17), 3);
      expect(a, b);
      expect(a, isNot(c));
      expect(a, greaterThanOrEqualTo(0));
      expect(a, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('PaymentSummary (AC-PAY-06 — angka identik)', () {
    final now = DateTime(2026, 10, 17);
    test('1 overdue + 1 due-soon → hitungan & next tepat', () {
      final s = PaymentSummary.fromRows(const [
        {'due_date': '2026-10-20', 'amount': 950000, 'status': 'unpaid'},
        {'due_date': '2026-10-10', 'amount': 900000, 'status': 'unpaid'},
        {'due_date': '2026-09-10', 'amount': 900000, 'status': 'paid'},
      ], now);
      expect(s.unpaidCount, 2);
      expect(s.overdueCount, 1);
      expect(s.nextDueDate, DateTime(2026, 10, 10));
      expect(s.nextAmount, 900000);
      expect(s.nextStatus, 'overdue');
    });
    test('urutan input tidak berpengaruh', () {
      final s = PaymentSummary.fromRows(const [
        {'due_date': '2026-11-01', 'amount': 1, 'status': 'unpaid'},
        {'due_date': '2026-10-12', 'amount': 2, 'status': 'unpaid'},
      ], now);
      expect(s.nextDueDate, DateTime(2026, 10, 12));
      expect(s.overdueCount, 1);
    });
    test('semua lunas / kosong → status paid, tanpa tanggal', () {
      final allPaid = PaymentSummary.fromRows(const [
        {'due_date': '2026-09-10', 'amount': 9, 'status': 'paid'},
      ], now);
      expect(allPaid.unpaidCount, 0);
      expect(allPaid.nextStatus, 'paid');
      expect(allPaid.nextDueDate, isNull);
      final empty = PaymentSummary.fromRows(const [], now);
      expect(empty.unpaidCount, 0);
      expect(empty.overdueCount, 0);
      expect(empty.nextAmount, isNull);
    });
    test('due kabisat dihitung benar', () {
      final s = PaymentSummary.fromRows(const [
        {'due_date': '2028-02-28', 'amount': 1, 'status': 'unpaid'},
      ], DateTime(2028, 3, 1));
      expect(s.nextStatus, 'overdue');
      expect(s.nextDueDate, DateTime(2028, 2, 28));
    });
  });
}
