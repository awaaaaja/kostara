import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/models.dart';

final _facilitiesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await Supabase.instance.client
      .from('facilities')
      .select('id, name')
      .order('name');
  return data;
});

const _genderLabels = {
  'any': 'Semua',
  'male_only': 'Putra',
  'female_only': 'Putri',
};
const _transportLabels = {
  'walk': 'Jalan kaki',
  'bike': 'Sepeda',
  'motorcycle': 'Motor',
  'public_transport': 'Angkutan umum',
};
const _distanceOptions = [1000, 2000, 3000, 5000, 10000];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  String _gender = 'any';
  String? _transport;
  int? _maxDistance = 3000;
  Campus? _campus;
  final Set<String> _facilityIds = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _budgetMin.dispose();
    _budgetMax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Sesi berakhir. Masuk kembali.');
      return;
    }
    try {
      await Supabase.instance.client.from('user_preferences').upsert({
        'user_id': user.id,
        'budget_min': int.parse(_budgetMin.text),
        'budget_max': int.parse(_budgetMax.text),
        'gender_preference': _gender,
        if (_campus != null) 'primary_campus_id': _campus!.id,
        if (_transport != null) 'transport_mode': _transport,
        if (_maxDistance != null) 'max_distance_m': _maxDistance,
        if (_facilityIds.isNotEmpty) 'facility_priority': _facilityIds.toList(),
      });
      ref.invalidate(hasPrefsProvider);
      ref.invalidate(searchResultProvider);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campuses = ref.watch(campusesProvider);
    final facilities = ref.watch(_facilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferensi kos')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Biar rekomendasi dan hasil pencarian lebih pas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMin,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget min (Rp)',
                      ),
                      validator: (v) => (v == null || int.tryParse(v) == null)
                          ? 'Wajib angka'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMax,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget max (Rp)',
                      ),
                      validator: (v) {
                        if (v == null || int.tryParse(v) == null) {
                          return 'Wajib angka';
                        }
                        final lo = int.tryParse(_budgetMin.text);
                        if (lo != null && int.parse(v) < lo) {
                          return 'Min > max';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Jenis kos', style: Theme.of(context).textTheme.labelLarge),
              SegmentedButton<String>(
                segments: [
                  for (final e in _genderLabels.entries)
                    ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {_gender},
                onSelectionChanged: (s) => setState(() => _gender = s.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Campus?>(
                initialValue: _campus,
                decoration: const InputDecoration(labelText: 'Kampus terdekat'),
                items: [
                  const DropdownMenuItem<Campus?>(
                    value: null,
                    child: Text('Belum memilih'),
                  ),
                  ...campuses.when(
                    data: (list) => list
                        .map(
                          (c) => DropdownMenuItem<Campus?>(
                            value: c,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    loading: () => const [],
                    error: (_, _) => const [],
                  ),
                ],
                onChanged: (c) => setState(() => _campus = c),
              ),
              if (_campus != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _maxDistance,
                  decoration: const InputDecoration(
                    labelText: 'Jarak maks ke kampus',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tidak dibatasi'),
                    ),
                    for (final d in _distanceOptions)
                      DropdownMenuItem<int?>(
                        value: d,
                        child: Text('${d ~/ 1000} km'),
                      ),
                  ],
                  onChanged: (d) => setState(() => _maxDistance = d),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _transport,
                decoration: const InputDecoration(labelText: 'Transportasi'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Belum memilih'),
                  ),
                  for (final e in _transportLabels.entries)
                    DropdownMenuItem<String?>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                ],
                onChanged: (v) => setState(() => _transport = v),
              ),
              const SizedBox(height: 16),
              Text(
                'Fasilitas penting',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              facilities.when(
                data: (list) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in list)
                      FilterChip(
                        label: Text('${f['name']}'),
                        selected: _facilityIds.contains('${f['id']}'),
                        onSelected: (sel) => setState(
                          () => sel
                              ? _facilityIds.add('${f['id']}')
                              : _facilityIds.remove('${f['id']}'),
                        ),
                      ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Gagal memuat fasilitas.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan preferensi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
