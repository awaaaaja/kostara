import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/reminder_service.dart';
import 'tenancy_repository.dart';

/// Resync pengingat saat layar sewa dibuka (ADR-006): baris `reminders`
/// server + notifikasi lokal mengikuti offsets tersimpan — regenerasi
/// tanpa duplikat (AC-PAY-05). Best-effort: kegagalan di sini tidak
/// menggagalkan layar.
final reminderSyncProvider = FutureProvider.family<void, String>((
  ref,
  tenancyId,
) async {
  final repo = ref.watch(tenancyRepositoryProvider);
  final offsets = await repo.reminderOffsets(tenancyId);
  final jobs = await repo.syncReminderRows(tenancyId, offsets);
  final service = ReminderService();
  await service.cancelForTenancy(tenancyId);
  for (final j in jobs) {
    await service.schedule(
      tenancyId: tenancyId,
      dueDate: j.dueDate,
      offsetDays: j.offset,
      title: 'Pengingat sewa',
      body:
          'Jatuh tempo ${j.dueDate.day.toString().padLeft(2, '0')}/'
          '${j.dueDate.month.toString().padLeft(2, '0')} · Rp${j.amount}',
    );
  }
});
