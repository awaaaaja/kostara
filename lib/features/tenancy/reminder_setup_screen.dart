import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/reminder_service.dart';
import '../../core/util/payment_schedule.dart';
import 'tenancy_repository.dart';

/// Offset tetap (FR-PAY-03/FR-NOT-01) + custom 1–30 hari.
const kReminderFixedOffsets = [7, 3, 1, 0];

/// Layar "Atur pengingat" (DESIGN §26): checklist 7/3/1/0 + Custom,
/// preview pengingat berikutnya, izin notifikasi diminta saat menyimpan (JIT).
class ReminderSetupScreen extends ConsumerStatefulWidget {
  const ReminderSetupScreen({super.key, required this.tenancyId});

  final String tenancyId;

  @override
  ConsumerState<ReminderSetupScreen> createState() =>
      _ReminderSetupScreenState();
}

class _ReminderSetupScreenState extends ConsumerState<ReminderSetupScreen> {
  Set<int> _selected = {};
  bool _customOn = false;
  int _customDays = 5;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _nextDue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(tenancyRepositoryProvider);
    try {
      final offsets = await repo.reminderOffsets(widget.tenancyId);
      final dues = await repo.upcomingDues(widget.tenancyId);
      if (!mounted) return;
      setState(() {
        _selected = offsets.toSet();
        _customOn = offsets.any((o) => o != 7 && o != 3 && o != 1 && o != 0);
        if (_customOn) {
          _customDays = offsets.firstWhere(
            (o) => o != 7 && o != 3 && o != 1 && o != 0,
            orElse: () => 5,
          );
        }
        _nextDue = dues.isEmpty ? null : dues.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<int> get _effectiveOffsets {
    final out = _selected.where(kReminderFixedOffsets.contains).toSet();
    if (_customOn) out.add(_customDays);
    return out.toList()..sort((a, b) => b.compareTo(a));
  }

  String get _preview {
    final offsets = _effectiveOffsets;
    if (offsets.isEmpty) return 'Pengingat mati';
    if (_nextDue == null) return 'Belum ada tagihan untuk diingatkan';
    final due = parseDateOnly(_nextDue!['due_date']);
    final minOffset = offsets.reduce((a, b) => a < b ? a : b);
    // WIB = UTC+7 tetap (tanpa DST) → preview selalu 09:00 WIB
    // meski perangkat di zona lain.
    final wib = reminderFireUtc(due, minOffset).add(const Duration(hours: 7));
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return 'Pengingat berikutnya:\n'
        '${wib.day} ${months[wib.month - 1]}, '
        '${wib.hour.toString().padLeft(2, '0')}:'
        '${wib.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final offsets = _effectiveOffsets;
    final service = ReminderService();
    try {
      // Izin notifikasi hanya saat user menyimpan pengingat (JIT).
      final granted = await service.requestPermission();
      final repo = ref.read(tenancyRepositoryProvider);
      await repo.saveReminderOffsets(widget.tenancyId, offsets);
      await service.cancelForTenancy(widget.tenancyId);
      final jobs = await repo.syncReminderRows(widget.tenancyId, offsets);
      for (final j in jobs) {
        await service.schedule(
          tenancyId: widget.tenancyId,
          dueDate: j.dueDate,
          offsetDays: j.offset,
          title: 'Pengingat sewa',
          body:
              'Jatuh tempo ${j.dueDate.day.toString().padLeft(2, '0')}/'
              '${j.dueDate.month.toString().padLeft(2, '0')} · '
              'Rp${j.amount}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !granted
                ? 'Pengingat disimpan. Izin notifikasi belum diberikan — '
                      'notifikasi mungkin tidak muncul.'
                : offsets.isEmpty
                ? 'Pengingat dimatikan.'
                : 'Pengingat disimpan.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Atur pengingat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Atur pengingat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Atur kapan kamu diingatkan sebelum jatuh tempo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (final o in kReminderFixedOffsets)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(o),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(o);
                } else {
                  _selected.remove(o);
                }
              }),
              title: Text(o == 0 ? 'Hari H' : '$o hari sebelum'),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _customOn,
            onChanged: (v) => setState(() => _customOn = v ?? false),
            title: const Text('Custom'),
          ),
          if (_customOn)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_customDays hari sebelum jatuh tempo'),
                  Slider(
                    value: _customDays.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$_customDays hari',
                    onChanged: (v) => setState(() => _customDays = v.round()),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          Text(
            _preview,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan pengingat'),
          ),
        ],
      ),
    );
  }
}
