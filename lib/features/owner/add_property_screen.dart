import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';

/// EWKB hex point (SRID 4326) — format yang diterima PostgREST untuk
/// kolom geography (GeoJSON ditolak parser).
String latLngToEwkbHex(double lat, double lng) {
  final b = BytesBuilder();
  b.addByte(1); // little endian
  final type = ByteData(4)..setUint32(0, 0x20000001, Endian.little);
  b.add(type.buffer.asUint8List());
  final srid = ByteData(4)..setUint32(0, 4326, Endian.little);
  b.add(srid.buffer.asUint8List());
  final coords = ByteData(16)
    ..setFloat64(0, lng, Endian.little)
    ..setFloat64(8, lat, Endian.little);
  b.add(coords.buffer.asUint8List());
  return b.toBytes().map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}

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
      await Supabase.instance.client.from('properties').insert({
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
      });
      _formKey.currentState?.reset();
      setState(() {
        _name.clear();
        _address.clear();
        _description.clear();
        _message =
            'Kos tersimpan. Listing aktif setelah diverifikasi super admin.';
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
