import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dialogs.dart';
import 'admin_repository.dart';

/// Master data facilities & campuses (FR-ADM-04, AC-ADM-05): toggle
/// is_active, tambah baru; nonaktif → penanda listing ikut terhapus (DB).
class AdminMasterScreen extends ConsumerWidget {
  const AdminMasterScreen({super.key});

  void _invalidate(WidgetRef ref) {
    ref.invalidate(adminFacilitiesProvider);
    ref.invalidate(adminCampusesProvider);
    ref.invalidate(adminOverviewProvider);
  }

  // ===== Facilities =====

  Future<void> _toggleFacility(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
    bool active,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!active) {
      final ok = await confirmAction(
        context,
        title: 'Nonaktifkan fasilitas',
        message:
            '"${row['name']}" berhenti tampil dan penanda listing pada '
            'fasilitas ini dihapus.',
        confirmLabel: 'Nonaktifkan',
      );
      if (!ok) return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .setFacilityActive('${row['id']}', active);
      _invalidate(ref);
      snack(
        messenger,
        active ? 'Fasilitas diaktifkan.' : 'Fasilitas dinonaktifkan.',
      );
    } catch (_) {
      snack(messenger, 'Gagal mengubah fasilitas.');
      _invalidate(ref);
    }
  }

  Future<void> _createFacility(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fasilitas baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama'),
              onChanged: (v) {
                slugCtrl.text = v
                    .toLowerCase()
                    .trim()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                    .replaceAll(RegExp(r'^-|-$'), '');
              },
            ),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(labelText: 'Slug (unik)'),
            ),
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(
                labelText: 'Kategori (opsional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final slug = slugCtrl.text.trim();
    if (name.isEmpty || slug.isEmpty) {
      snack(messenger, 'Nama dan slug wajib diisi.');
      return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .createFacility(slug: slug, name: name, category: catCtrl.text);
      _invalidate(ref);
      snack(messenger, 'Fasilitas ditambahkan.');
    } catch (_) {
      snack(messenger, 'Gagal — slug mungkin sudah dipakai.');
    } finally {
      nameCtrl.dispose();
      slugCtrl.dispose();
      catCtrl.dispose();
    }
  }

  // ===== Campuses =====

  Future<void> _toggleCampus(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
    bool active,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!active) {
      final ok = await confirmAction(
        context,
        title: 'Nonaktifkan kampus',
        message: '"${row['name']}" tidak lagi muncul di pencarian kampus.',
        confirmLabel: 'Nonaktifkan',
      );
      if (!ok) return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .setCampusActive('${row['id']}', active);
      _invalidate(ref);
      snack(messenger, active ? 'Kampus diaktifkan.' : 'Kampus dinonaktifkan.');
    } catch (_) {
      snack(messenger, 'Gagal mengubah kampus.');
      _invalidate(ref);
    }
  }

  Future<void> _createCampus(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '-0.92');
    final lngCtrl = TextEditingController(text: '100.40');
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kampus baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama kampus'),
            ),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
            ),
            TextField(
              controller: latCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            TextField(
              controller: lngCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final lat = double.tryParse(latCtrl.text.trim());
    final lng = double.tryParse(lngCtrl.text.trim());
    if (name.length < 3 || lat == null || lng == null) {
      snack(messenger, 'Nama (min. 3) dan koordinat wajib valid.');
      return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .createCampus(name: name, address: addrCtrl.text, lat: lat, lng: lng);
      _invalidate(ref);
      snack(messenger, 'Kampus ditambahkan.');
    } catch (_) {
      snack(messenger, 'Gagal menambah kampus.');
    } finally {
      nameCtrl.dispose();
      addrCtrl.dispose();
      latCtrl.dispose();
      lngCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilities = ref.watch(adminFacilitiesProvider);
    final campuses = ref.watch(adminCampusesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Data master'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fasilitas'),
              Tab(text: 'Kampus'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Fasilitas ---
            facilities.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat fasilitas.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(adminFacilitiesProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminFacilitiesProvider),
                    child: list.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Belum ada fasilitas.'),
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              for (final row in list)
                                ListTile(
                                  dense: true,
                                  title: Text('${row['name']}'),
                                  subtitle: Text(
                                    '${row['slug']}'
                                    '${row['category'] != null ? ' · ${row['category']}' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: row['is_active'] == true,
                                        onChanged: (v) => _toggleFacility(
                                          context,
                                          ref,
                                          row,
                                          v,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: 'Opsi fasilitas',
                                        onSelected: (v) {
                                          if (v == 'off') {
                                            _toggleFacility(
                                              context,
                                              ref,
                                              row,
                                              false,
                                            );
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'off',
                                            child: Text('Nonaktifkan'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      tooltip: 'Tambah fasilitas',
                      onPressed: () => _createFacility(context, ref),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
            // --- Kampus ---
            campuses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat kampus.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(adminCampusesProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(adminCampusesProvider),
                    child: list.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Belum ada kampus.'),
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              for (final row in list)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.school_outlined),
                                  title: Text('${row['name']}'),
                                  subtitle: Text('${row['address'] ?? '—'}'),
                                  trailing: Switch(
                                    value: row['is_active'] == true,
                                    onChanged: (v) =>
                                        _toggleCampus(context, ref, row, v),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      tooltip: 'Tambah kampus',
                      onPressed: () => _createCampus(context, ref),
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
