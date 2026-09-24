# CP-01 — Interview Plan & Script

Date: 2026-09-25
Status: instrumen siap dilaksanakan; pelaksanaan PENDING (oleh pemilik project).

Tujuan: membuktikan/menolak H-01..H-05 dan A-01..A-09 (`cp01-assumptions.md`)
tanpa memimpin partisipan ke jawaban yang diinginkan.

---

## 1. Pelaksanaan

| Item | Aturan |
|---|---|
| Jumlah | seeker 3-5; owner 2-3 (PRD §4.2) |
| Durasi | 20-40 menit per sesi |
| Metode | wawancara semi-terstruktur, boleh tatap muka/telepon |
| Pencatatan | catatan + (opsional, dengan izin) rekaman audio lokal; ringkasan ke evidence log |
| Identitas | beri kode S1-01..; JANGAN simpan nama/NIM/alamat di repo |
| Izin | sebutkan tujuan riset Capstone, bahwa partisipasi sukarela, boleh berhenti kapan saja |
| Larangan | jangan menyebut "aplikasi kami pakai AI" sebelum bagian §3.5 — agar tidak bias |

## 2. Script — Seeker (S1)

**Pembuka:** "Saya sedang riset pengalaman mencari kos untuk tugas kuliah. Tidak ada jawaban salah. Semua bersifat sukarela."

1. **Proses terakhir:** "Ceritakan saat terakhir kamu mencari/pindah kos. Mulai dari mana? Pakai apa (grup WA, Instagram, situs, kenalan)?"
2. **Kriteria:** "Apa yang bikin sebuah kos masuk daftar pendek? Apa yang bikin gugur? Urutkan kalau bisa."
3. **Usaha & waktu:** "Berapa lama kira-kira dari mulai cari sampai mantap pilih? Bagian mana yang paling melelahkan?"
4. **Jarak/kampus:** "Bagaimana kamu menilai jarak/waktu ke kampus? Pernah salah perkiraan?"
5. **Trust review:** "Seberapa kamu percaya review di aplikasi sekarang? Pernah merasa review palsu/tidak relevan? Gimana cara kamu menyaringnya?"
6. **Setelah pindah:** "Sewa, pengingat, komunikasi sama pemilik, laporan kerusakan — sekarang dicatat/dimanage gimana? Pernah telat bayar atau lupa?"
7. **Keputusan sulit:** "Pernah ada situasi banyak pilihan tapi bingung pilih? Kenapa filter (kalau pakai aplikasi) tidak membantu saat itu?"
8. **Selera produk:** "Kalau ada yang bisa mengurangi satu hal dari daftar tadi, apa yang paling berdampak buat kamu?"

## 3. Script — Owner (S2)

**Pembuka:** sama — riset Capstone, sukarela, tanpa menyebut AI di awal.

1. **Operasional harian:** "Bagaimana kamu mencatat kamar kosong/terisi hari ini? Pakai alat apa?"
2. **Pencari & seleksi:** "Calon penghuni datang dari mana? Bagaimana kamu memilih/menyeleksi? Pernah ada double-booking atau kamar dianggap kosong padahal tidak?"
3. **Pembayaran:** "Bagaimana kamu mencatat pembayaran? Pernah ada salah catat/selisih? Pengingat bagaimana (manual WA?)?"
4. **Feedback:** "Dapat masukan penghuni lewat mana? Pernah ada keluhan yang tidak sampai/sulit dilacak? Butuh ringkasan aspek (kebersihan, internet, dst.)?"
5. **Listing & kepercayaan:** "Bagaimana calon penghuni tahu kos kamu bonafide? Pernah ada pihak pura-pura/pemalsuan?"
6. **Beban terbesar:** "Satu hal operasional yang paling menyita waktu minggu ini?"

## 4. Script — Operator/admin mini (opsional, 1 orang internal)

1. Saat ini verifikasi/moderasi dilakukan bagaimana?
2. Apa yang harus tercatat agar keputusan bisa diaudit?
3. Apa risiko terbesar bila platform tanpa moderasi?

## 5. Analisis setelah tiap sesi

1. Isi `cp01-evidence-log.md` (kode partisipan, kutipan kunci, hipotesis yang didukung/ditolak).
2. Perbarui status A-xx di `cp01-assumptions.md` (validated / rejected / unknown).
3. Perbarui pain H-xx di `cp01-charter-and-problem.md` dari hipotesis → berbukti (atau tolak).
4. Update `RISK_REGISTER.md` bila asumsi berubah.
5. Gate CP-01 boleh dievaluasi ulang hanya jika evidence log berisi entri nyata.
