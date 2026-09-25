import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/ewkb.dart';
import '../auth/auth_repository.dart';
import 'owner_repository.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _lat = TextEditingController(text: '-0.92');
  final _lng = TextEditingController(text: '100.40');
  String _gender = 'any';
  final _photos = <XFile>[];
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked.isEmpty) return;
    setState(() {
      // Maksimal 8 foto per listing (hemat kuota bucket 5 MB/file).
      _photos.addAll(picked.take(8 - _photos.length));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _message = 'Sesi berakhir. Masuk kembali.');
      return;
    }
    try {
      final inserted = await Supabase.instance.client
          .from('properties')
          .insert({
            'owner_id': user.id,
            'name': _name.text.trim(),
            'address': _address.text.trim(),
            'description': _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            'gender_policy': _gender,
            'location': latLngToEwkbHex(
              double.parse(_lat.text),
              double.parse(_lng.text),
            ),
          })
          .select('id')
          .single();
      var photoNote = '';
      if (_photos.isNotEmpty) {
        try {
          await ref.read(ownerRepositoryProvider).uploadPropertyPhotos(
            inserted['id'] as String,
            [for (final p in _photos) p.path],
          );
          _photos.clear();
        } catch (_) {
          photoNote = ' Foto gagal diunggah — tambahkan lewat kelola kos.';
        }
      }
      _formKey.currentState?.reset();
      setState(() {
        _name.clear();
        _address.clear();
        _description.clear();
        _message =
            'Kos tersimpan. Listing aktif setelah diverifikasi super '
            'admin.$photoNote';
      });
    } catch (e) {
      setState(() => _message = 'Gagal menyimpan. Periksa data dan coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          const Scaffold(body: Center(child: Text('Gagal memuat profil.'))),
      data: (p) {
        if (p == null || !p.isOwner) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tambah kos')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Fitur ini hanya untuk pemilik kos.'),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Tambah kos')),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nama kos'),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.length < 3 || t.length > 120) {
                        return '3–120 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Alamat lengkap',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (opsional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null)
                              ? 'Angka valid'
                              : (double.parse(v).abs() > 90
                                    ? 'Di luar rentang'
                                    : null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lng,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                          validator: (v) =>
                              (v == null || double.tryParse(v) == null)
                              ? 'Angka valid'
                              : (double.parse(v).abs() > 180
                                    ? 'Di luar rentang'
                                    : null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Titik peta diambil dari kolom alamat/kantor (jangan menampilkan alamat penghuni).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'any', label: Text('Campur')),
                      ButtonSegment(value: 'male_only', label: Text('Putra')),
                      ButtonSegment(value: 'female_only', label: Text('Putri')),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) =>
                        setState(() => _gender = s.first),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Foto',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _photos.length >= 8 ? null : _pickPhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(_photos.isEmpty ? 'Tambah' : 'Tambah lagi'),
                      ),
                    ],
                  ),
                  if (_photos.isNotEmpty)
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_photos[i].path),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _photos.removeAt(i)),
                                child: Icon(
                                  Icons.cancel,
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.startsWith('Gagal')
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan kos'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
