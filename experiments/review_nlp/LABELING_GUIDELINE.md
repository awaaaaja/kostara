# Labeling Guideline & Aspect Taxonomy — ML-2 Review NLP (v0)

Status: **guideline terkunci; label BELUM ada** (CP-03B).
Metrik model = N/A sampai ada label nyata (AGENTS §4.4 — jangan mengarang).

## 1. Taxonomy aspek (8, terkunci — cp02-ml-data-plan B2)

| key | definisi operasional | cue umum |
|---|---|---|
| cleanliness | kebersihan kamar/area, debu, kebersihan umum | bersih, kumuh, debu |
| security | keamanan fisik & akses, penghuni, barang | aman, gerbang, curian |
| internet | WiFi/kuota/stabilitas koneksi | wifi lambat, sinyal |
| water | air bersih, tekanan, mati air, panas | air mati, panas |
| comfort | kenyamanan ruang, suhu, ukuran, kebisingan | sejuk, sempit, berisik |
| access | jarak/aksesibilitas ke jalan/kampus, parkir | dekat kampus, gang sempit |
| owner | respons/responsivitas/pengelolaan pemilik | ramah, lambat respon |
| value | kesesuaian harga dengan mutu | worth it, mahal |

Label per baris-aspek: `positive | negative | neutral | insufficient_evidence`.

## 2. Aturan anotasi

1. Baca satu review → ekstrak kalimat per aspek → buat baris **hanya untuk
   aspek yang disebut** (aspek tidak disebut = tidak ada baris, bukan
   neutral).
2. Dua opini bertentangan pada aspek yang sama → `neutral` + catatan;
   yakin salah satu dominan → label dominan.
3. Sindiran negatif tanpa kata eksplisit → boleh dipahami dari konteks;
   meragukan → `insufficient_evidence`.
4. Low-confidence pada tahap inferensi → `insufficient_evidence`
   (guardrail PRD).
5. Jangan menyimpulkan fakta objektif dari opini.
6. Jangan menulis identitas (nama, nomor) ke dalam kolom apa pun — teks
   review asli tidak pernah diubah (AC-NLP-03).

## 3. Strategi labeling (cp02 B3)

1. Anotasi manual subset oleh tim, ≥2 anotator.
2. Inter-annotator check (Cohen's kappa) pada ≥20% sampel.
3. kappa ≤ 0.6 → diskusi & revisi guideline sebelum lanjut.
4. Baseline lexicon/keyword berjalan **tanpa label** (ekspor fitur/matrix);
   classifier terlatih hanya bila jumlah label memadai.
5. Distribusi label, kebijakan missing, dan PII dibuat dataset card ML-2
   saat data anotasi pertama ada.

## 4. Data saat ini (jujur)

- Review platform: 3 approved + 1 pending (dev seed) — **belum ada label
  aspek**; `review_aspect_scores` berisi baris sumber `manual` untuk
  pengujian skema, bukan hasil NLP.
- Keputusan kandidat model (lexicon → linear → transformer) ditunda sampai
  ada data label nyata; tidak ada confusion matrix/macro-F1 yang boleh
  dilaporkan sebelum run pada data berlabel.
