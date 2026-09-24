# KOSTARA — Capstone Project Documentation Pack

**Product:** KOSTARA  
**Working title:** *Pengembangan Aplikasi Mobile Pencarian dan Manajemen Kos Menggunakan Hybrid Recommendation System Berbasis Preferensi, Geospatial Intelligence, dan Analisis Feedback Penghuni*  
**Primary stack:** Flutter + Supabase + PostgreSQL/PostGIS  
**AI/ML:** Hybrid Recommendation System + Aspect-Based Review Sentiment Analysis  
**Primary target:** Mahasiswa/pencari kos, pemilik kos, dan operator platform. Pilot awal dapat difokuskan pada Kota Padang.

Dokumen ini disusun sebagai source of truth untuk pengerjaan Capstone KOSTARA dengan AI coding agent.

## Dokumen

1. [PRD.md](./PRD.md)  
   Product Requirements Document. Menjelaskan masalah, stakeholder, scope, role, user flow, fitur, ML/GIS, data, arsitektur, acceptance criteria, keamanan, dan alignment Capstone.

2. [AGENTS.md](./AGENTS.md)  
   Aturan kerja untuk AI coding agent. Wajib dibaca sebelum menulis atau mengubah kode. Berisi konteks kuat, boundary, urutan kerja, rules Flutter/Supabase/ML, dan format laporan.

3. [DESIGN.md](./DESIGN.md)  
   Sistem UI/UX mobile-first. Berisi visual direction, design tokens, navigation, screen specification, map UX, motion, loading/error/empty state, accessibility, dan interaction rules.

4. [SPRINTS.md](./SPRINTS.md)  
   Roadmap 16 minggu yang disejajarkan dengan CP-00 sampai CP-05.

5. [VALIDATION_PROTOCOL.md](./VALIDATION_PROTOCOL.md)  
   Quality gate wajib: **THINK → BUILD → REVIEW → FIX → PASS**. Tidak boleh melanjutkan fase bila gate belum PASS.

6. [PROMPTS.md](./PROMPTS.md)  
   Prompt execution pack untuk setiap sprint CP-00 sampai CP-05, termasuk mandatory pre-flight yang memaksa AI agent membaca seluruh dokumentasi dan mengaudit codebase aktual sebelum mulai bekerja.

## Aturan sumber kebenaran

Jika ada konflik, gunakan urutan berikut:

1. Instruksi eksplisit terbaru dari pemilik project.
2. `VALIDATION_PROTOCOL.md` untuk aturan gate dan kualitas.
3. `PRD.md` untuk scope dan requirement produk.
4. `DESIGN.md` untuk UI/UX.
5. `SPRINTS.md` untuk urutan implementasi.
6. `AGENTS.md` untuk cara AI agent bekerja.

Namun, untuk AI coding agent, `AGENTS.md` tetap wajib dibaca pertama agar agent memahami cara membaca seluruh source of truth.

## Alignment dengan Panduan Capstone Informatika Universitas Adzkia 2026

Dokumentasi ini sengaja mengikuti struktur stage-gate pada Panduan Capstone:

- CP-00: persiapan, tim, topik, repository.
- CP-01: validasi masalah dan stakeholder.
- CP-02: kebutuhan, data, acceptance criteria, test plan.
- CP-03: alternatif, arsitektur, model, baseline/prototype.
- CP-04: implementasi, integrasi, reproducibility.
- CP-05: verifikasi, validasi manfaat, deployment/demo.

Panduan juga menuntut proyek AI memiliki dataset yang legal dan terdokumentasi, baseline dan alternatif model, evaluasi, reproducibility, responsible AI, model terintegrasi ke aplikasi, serta bukti proses dan kontribusi individual.

## Prinsip produk

KOSTARA **bukan sekadar marketplace/listing kos**.

Nilai utamanya adalah:

- menemukan kos yang relevan secara personal;
- mempertimbangkan budget, fasilitas, preferensi, lokasi, kampus/tujuan utama, dan feedback penghuni;
- menyediakan Explore Map dan nearby search;
- menjaga lifecycle setelah user menjadi penghuni;
- menyediakan pengingat pembayaran dan riwayat tenancy;
- memastikan feedback berasal dari verified tenant;
- memberi intelligence kepada pemilik kos;
- menghasilkan interaction dataset yang memungkinkan model rekomendasi berkembang.

## Core ML

### ML-1 — Hybrid Recommendation System

Baseline wajib:

- popularity/rule-based baseline;
- content-based recommendation.

Kandidat model:

- content-based similarity;
- LightFM atau hybrid collaborative filtering ketika interaksi cukup;
- ranking model yang menggunakan user, property, geospatial, dan review features.

Evaluasi:

- Precision@K;
- Recall@K;
- NDCG@K;
- Hit Rate;
- coverage;
- evaluasi cold-start;
- user/stakeholder validation.

### ML-2 — Aspect-Based Review Sentiment Analysis

Input: review verified tenant.  
Output: sentiment per aspek seperti kebersihan, keamanan, internet, air, kenyamanan, akses, dan pemilik.

Baseline dan kandidat:

- TF-IDF + linear classifier sebagai baseline;
- model Bahasa Indonesia berbasis transformer sebagai kandidat bila dataset memadai.

Evaluasi:

- Macro F1;
- Precision;
- Recall;
- confusion/error analysis.

**Dilarang membuat atau mengarang metrik model. Semua angka harus berasal dari eksperimen nyata.**

## GIS

GIS bukan dekorasi map. GIS harus memengaruhi pencarian dan rekomendasi:

- koordinat kos dan kampus;
- nearby query;
- distance filtering;
- spatial index;
- current location dengan izin;
- travel time hanya jika ada routing provider yang valid;
- isochrone sebagai target P1 bila feasibility dan data routing memungkinkan.

## V1 yang harus selesai

V1 dianggap selesai jika:

- seeker dapat onboarding, search, explore map, save, compare, melihat rekomendasi, request tenancy, dan menggunakan tenancy/payment reminder;
- owner dapat mengelola listing, kamar, availability, tenancy, pembayaran, dan feedback;
- super admin dapat melakukan verifikasi dan moderasi;
- recommendation baseline dan model terpilih dapat dievaluasi dan terintegrasi;
- review analysis bekerja pada data tervalidasi;
- seluruh akses data dilindungi RLS;
- aplikasi dapat didemonstrasikan secara stabil;
- acceptance criteria utama lulus;
- artefak Capstone terdokumentasi.

## Catatan penting untuk AI agent

Jangan mulai coding dengan asumsi. Baca:

`AGENTS.md` → `PRD.md` → `DESIGN.md` → `SPRINTS.md` → `VALIDATION_PROTOCOL.md` → `PROMPTS.md` → `README.md`

Lalu lakukan fase pertama dengan:

**THINK → BUILD → REVIEW → FIX → PASS**
