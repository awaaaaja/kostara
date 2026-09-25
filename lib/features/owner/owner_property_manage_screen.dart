import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'owner_repository.dart';

class OwnerPropertyManageScreen extends ConsumerStatefulWidget {
  const OwnerPropertyManageScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<OwnerPropertyManageScreen> createState() =>
      _OwnerPropertyManageScreenState();
}

class _OwnerPropertyManageScreenState
    extends ConsumerState<OwnerPropertyManageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  String _gender = 'any';
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .updateProperty(
            widget.propertyId,
            fields: {
              'name': _name.text.trim(),
              'address': _address.text.trim(),
              'description': _description.text.trim(),
              'rules': _rules.text.trim(),
              'gender_policy': _gender,
            },
          );
      ref.invalidate(ownerPropertiesProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Perubahan disimpan.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
      );
    }
  }

  Future<void> _roomDialog({Map<String, dynamic>? room}) async {
    final code = TextEditingController(text: room?['code'] ?? '');
    final price = TextEditingController(
      text: room == null ? '' : '${room['price']}',
    );
    final deposit = TextEditingController(
      text: room == null ? '' : '${room['deposit'] ?? 0}',
    );
    var type = '${room?['room_type'] ?? 'single'}';
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(room == null ? 'Tambah kamar' : 'Ubah kamar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Kode kamar'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Single')),
                  DropdownMenuItem(value: 'shared', child: Text('Shared')),
                  DropdownMenuItem(value: 'studio', child: Text('Studio')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'single'),
                decoration: const InputDecoration(labelText: 'Tipe'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga / bulan'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deposit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Deposit'),
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
      ),
    );
    if (saved != true) return;
    try {
      if (room == null) {
        await ref
            .read(ownerRepositoryProvider)
            .addRoom(
              widget.propertyId,
              code: code.text.trim(),
              roomType: type,
              price: int.tryParse(price.text) ?? 0,
              deposit: int.tryParse(deposit.text) ?? 0,
            );
      } else {
        await ref
            .read(ownerRepositoryProvider)
            .updateRoom(room['id'] as String, {
              'code': code.text.trim(),
              'room_type': type,
              'price': int.tryParse(price.text) ?? 0,
              'deposit': int.tryParse(deposit.text) ?? 0,
            });
      }
      ref.invalidate(ownerPropertyRoomsProvider);
      ref.invalidate(ownerPropertiesProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan kamar (kode mungkin kembar).'),
        ),
      );
    } finally {
      code.dispose();
      price.dispose();
      deposit.dispose();
    }
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus kamar?'),
        content: Text('Kamar ${room['code']} akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ownerRepositoryProvider).deleteRoom(room['id'] as String);
      ref.invalidate(ownerPropertyRoomsProvider);
      ref.invalidate(ownerPropertiesProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus kamar.')),
      );
    }
  }

  Future<void> _deletePhoto(String storagePath) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus foto?'),
        content: const Text('Foto akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(ownerRepositoryProvider)
          .deletePropertyPhoto(widget.propertyId, storagePath);
      ref.invalidate(ownerPropertiesProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus foto.')),
      );
    }
  }

  Future<void> _addPhotos() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return;
    try {
      await ref.read(ownerRepositoryProvider).uploadPropertyPhotos(
        widget.propertyId,
        [for (final p in picked) p.path],
      );
      ref.invalidate(ownerPropertiesProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengunggah foto. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(ownerPropertiesProvider);
    final rooms = ref.watch(ownerPropertyRoomsProvider(widget.propertyId));
    final scheme = Theme.of(context).colorScheme;

    final prop = properties.valueOrNull?.where(
      (p) => p['id'] == widget.propertyId,
    );
    if (prop != null && prop.isNotEmpty && !_hydrated) {
      final p = prop.first;
      _name.text = '${p['name']}';
      _address.text = '${p['address']}';
      _description.text = '${p['description'] ?? ''}';
      _rules.text = '${p['rules'] ?? ''}';
      _gender = '${p['gender_policy']}';
      _hydrated = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola kos')),
      body: properties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Gagal memuat properti.')),
        data: (rows) {
          final row = rows.firstWhere(
            (p) => p['id'] == widget.propertyId,
            orElse: () => <String, dynamic>{},
          );
          final images =
              ((row['property_images'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>()
                ..sort((a, b) {
                  final ai = a['is_cover'] == true ? 1 : 0;
                  final bi = b['is_cover'] == true ? 1 : 0;
                  if (ai != bi) return bi - ai;
                  return ((b['sort_order'] ?? 0) as num).compareTo(
                    (a['sort_order'] ?? 0) as num,
                  );
                });
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nama kos'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Minimal 3 karakter'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Alamat'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Untuk'),
                      items: const [
                        DropdownMenuItem(value: 'any', child: Text('Campur')),
                        DropdownMenuItem(
                          value: 'male_only',
                          child: Text('Putra'),
                        ),
                        DropdownMenuItem(
                          value: 'female_only',
                          child: Text('Putri'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'any'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Deskripsi'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rules,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Peraturan'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Simpan perubahan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Foto',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              if (images.isEmpty)
                Text(
                  'Belum ada foto.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final path = '${images[i]['storage_path']}';
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              Supabase.instance.client.storage
                                  .from('property-images')
                                  .getPublicUrl(path),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 96,
                                height: 96,
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.outline,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _deletePhoto(path),
                              child: Icon(
                                Icons.cancel,
                                size: 20,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kamar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _roomDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              rooms.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => const Text('Gagal memuat kamar.'),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'Belum ada kamar.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: [
                      for (final r in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.meeting_room_outlined),
                          title: Text('${r['code']} · ${r['room_type']}'),
                          subtitle: Text('Rp${r['price']} · ${r['status']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Ubah',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _roomDialog(room: r),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: scheme.error,
                                ),
                                onPressed: () => _deleteRoom(r),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
