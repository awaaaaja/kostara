// Kalkulator pembayaran & pengingat (FR-PAY-01..03, AC-PAY-01..06).
//
// Satu sumber status untuk home owner & tenant (AC-PAY-06): DB hanya
// menyimpan {unpaid, paid}; 'overdue' dihitung dari tanggal di sini.

/// Status efektif: `overdue` bila unpaid dan hari ini melewati due date
/// (AC-PAY-02). [dueDate]/[now] dipakai bagian tanggalnya saja.
String effectivePaymentStatus(String status, DateTime dueDate, DateTime now) {
  if (status != 'unpaid') return status;
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.isAfter(due) ? 'overdue' : 'unpaid';
}

/// Label status — wording tenang, tanpa mengintimidasi (DESIGN §25/§40).
String paymentStatusLabel(String status) => switch (status) {
  'paid' => 'Lunas',
  'overdue' => 'Terlambat',
  _ => 'Belum dibayar',
};

/// Sisa hari sampai jatuh tempo: "Jatuh tempo hari ini" /
/// "Jatuh tempo dalam 6 hari" / "Lewat 2 hari dari jatuh tempo".
String dueInLabel(DateTime dueDate, DateTime now) {
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = due.difference(today).inDays;
  if (days == 0) return 'Jatuh tempo hari ini';
  if (days > 0) return 'Jatuh tempo dalam $days hari';
  return 'Lewat ${-days} hari dari jatuh tempo';
}

/// Parse tanggal pola `yyyy-MM-dd` (date-only dari DB) tanpa geser zona
/// waktu perangkat — bagian tanggal dipakai apa adanya.
DateTime parseDateOnly(Object? value) {
  if (value == null) return DateTime.now();
  final s = '$value';
  final d = DateTime.tryParse(s);
  if (d == null) return DateTime.now();
  return DateTime(d.year, d.month, d.day);
}

/// Waktu pengingat: pukul 09:00 Asia/Jakarta (WIB, tanpa DST → 02:00 UTC)
/// pada [dueDate] − [offsetDays] hari (AC-PAY-03, DESIGN §26 preview).
/// Kembali dalam UTC instan; konversi zona dilakukan ReminderService.
DateTime reminderFireUtc(DateTime dueDate, int offsetDays) {
  final nineWibUtc = DateTime.utc(dueDate.year, dueDate.month, dueDate.day, 2);
  return nineWibUtc.subtract(Duration(days: offsetDays));
}

/// Id notifikasi lokal deterministik per tenancy+due+offset.
/// `& 0x7fffffff` agar aman untuk id 31-bit Android.
int reminderNotificationId(String tenancyId, DateTime dueDate, int offset) =>
    (Object.hash(
      tenancyId,
      dueDate.year * 10000 + dueDate.month * 100 + dueDate.day,
      offset,
    )) &
    0x7fffffff;

/// Ringkasan tagihan untuk banner home — dipakai persis oleh home seeker dan
/// dashboard owner sehingga angkanya identik (AC-PAY-06).
class PaymentSummary {
  const PaymentSummary({
    required this.unpaidCount,
    required this.overdueCount,
    required this.nextDueDate,
    required this.nextAmount,
    required this.nextStatus,
  });

  final int unpaidCount;
  final int overdueCount;
  final DateTime? nextDueDate;
  final int? nextAmount;
  final String nextStatus; // unpaid | overdue | paid (nextDueDate null → paid)

  /// [rows] = payment_records (due_date, amount, status) milik pihak itu.
  factory PaymentSummary.fromRows(
    List<Map<String, dynamic>> rows,
    DateTime now,
  ) {
    final open = rows.where((r) => r['status'] != 'paid').toList()
      ..sort(
        (a, b) => parseDateOnly(
          a['due_date'],
        ).compareTo(parseDateOnly(b['due_date'])),
      );
    final overdue = open
        .where(
          (r) =>
              effectivePaymentStatus(
                'unpaid',
                parseDateOnly(r['due_date']),
                now,
              ) ==
              'overdue',
        )
        .length;
    if (open.isEmpty) {
      return PaymentSummary(
        unpaidCount: 0,
        overdueCount: 0,
        nextDueDate: null,
        nextAmount: null,
        nextStatus: 'paid',
      );
    }
    final next = open.first;
    final due = parseDateOnly(next['due_date']);
    return PaymentSummary(
      unpaidCount: open.length,
      overdueCount: overdue,
      nextDueDate: due,
      nextAmount: (next['amount'] as num?)?.toInt(),
      nextStatus: effectivePaymentStatus('unpaid', due, now),
    );
  }
}
