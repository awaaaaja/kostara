# DESIGN.md — KOSTARA UI/UX System

**Platform:** Flutter mobile-first  
**Visual direction:** Calm, modern, trustworthy property utility  
**Primary context:** Pencari kos mahasiswa + pemilik kos + admin  
**Design rule:** Interaktif, ringan, informatif, bukan "AI dashboard template"

---

# 1. Design Vision

KOSTARA harus terasa seperti:

- aplikasi properti yang modern;
- utility yang dipakai berulang;
- map-first saat eksplorasi;
- tenang dan terpercaya saat tenancy/payment;
- cepat dipahami tanpa tutorial panjang.

KOSTARA tidak boleh terasa seperti:

- landing page SaaS yang dipindahkan ke mobile;
- dashboard berisi 20 card;
- UI penuh gradient, glow, dan glassmorphism;
- aplikasi AI yang menonjolkan "AI" di semua tempat;
- template marketplace generik.

Machine Learning bekerja di belakang. UI menonjolkan **manfaat**, bukan jargon model.

---

# 2. Design Principles

## 2.1 Utility before decoration

Setiap elemen harus membantu:

- menemukan;
- membandingkan;
- memutuskan;
- mengelola;
- mengingat.

## 2.2 Map and list as one experience

Explore Map dan listing bukan dua aplikasi berbeda.

Map state, filter, dan selected property harus tersinkron.

## 2.3 Progressive disclosure

Jangan menampilkan semua detail di home.

Contoh:

Home → recommendation card → property detail → room detail.

## 2.4 Trust by evidence

Tampilkan:

- verified owner;
- verified tenant review;
- availability update;
- last updated;
- explanation recommendation.

## 2.5 Calm interaction

Gunakan motion pendek dan fungsional.

Tidak ada animation yang menghambat task.

---

# 3. Brand Direction

Nama: **KOSTARA**

Karakter:

- reliable;
- local;
- warm;
- useful;
- modern;
- not childish.

---

# 4. Color System

Gunakan palette netral-hangat dengan primary hijau yang terasa properti/kepercayaan.

```text
Background       #F7F6F2
Surface          #FFFFFF
Surface Soft     #ECF1ED
Primary          #176B52
Primary Dark     #0F4F3C
Primary Soft     #DDEAE4
Accent           #D9A447
Text Primary     #18221E
Text Secondary   #66736D
Line             #DDE2DE
Danger           #B94343
Warning          #B07822
Success          #25785D
Info             #326B91
```

Rules:

- primary untuk action utama;
- accent hanya untuk highlight tertentu;
- danger tidak digunakan sebagai dekorasi;
- map marker selection harus jelas;
- jangan menggunakan >2 accent kuat dalam satu screen.

---

# 5. Typography

Recommended: **Plus Jakarta Sans**

Scale:

```text
Display    30/36  700
H1         26/32  700
H2         22/28  700
H3         18/24  650
Body L     16/24  500
Body       14/21  500
Caption    12/18  500
Label      12/16  650
```

Rules:

- jangan gunakan uppercase panjang;
- harga harus mudah dipindai;
- line height cukup lega;
- nama kos maksimal 2 baris di card;
- long description pada detail menggunakan expand/collapse.

---

# 6. Spacing

4pt base grid.

```text
4
8
12
16
20
24
32
40
48
```

Default screen horizontal padding:

```text
16dp phone kecil
20dp phone lebar
```

Jangan menambah whitespace ekstrem hanya agar terlihat "premium".

---

# 7. Radius

```text
Button       12
Input        12
Card         16
Bottom sheet 20 top corners
Image        14-16
Chip         10-12
```

Tidak semua komponen harus berbentuk pill.

---

# 8. Iconography

Gunakan icon set konsisten.

Rules:

- no emoji sebagai icon;
- icon line/rounded;
- label tetap digunakan pada action yang ambigu;
- icon warna mengikuti semantic state.

---

# 9. Elevation

Gunakan minimal.

Default:

- surface biasa: 0;
- floating search/map controls: subtle;
- bottom sheet: subtle;
- selected card: line/contrast lebih penting daripada shadow besar.

---

# 10. Motion

Durations:

```text
Micro feedback      120-160ms
Navigation          180-240ms
Bottom sheet        220-300ms
Map card transition 180-240ms
Skeleton shimmer    subtle only
```

Motion examples:

- favorite heart/icon state;
- filter apply;
- map marker selection;
- bottom sheet expand;
- role switch only if product supports it later.

Haptic:

- save favorite;
- successful tenancy request;
- important confirmation.

Jangan gunakan haptic pada setiap tap.

---

# 11. Navigation — Seeker/Tenant

Bottom navigation:

```text
Home
Explore
Saved
Tenancy
Profile
```

Saat seeker belum punya tenancy:

`Tenancy` menampilkan empty state informatif.

Saat tenancy aktif:

tab tersebut menjadi pusat payment/reminder/feedback.

---

# 12. Navigation — Owner

Bottom navigation:

```text
Home
Properties
Tenants
Payments
Profile
```

Add property dapat berupa primary floating action hanya di screen Properties, bukan global FAB.

---

# 13. Navigation — Super Admin

Karena admin biasanya lebih cocok desktop, V1 mobile tetap dapat menyediakan operational views:

```text
Dashboard
Verification
Reports
Models
Profile
```

Jika scope admin menjadi kompleks, admin web dapat menjadi V2 tanpa mengubah core mobile Capstone.

---

# 14. Seeker Home

Struktur:

```text
Top bar
- greeting
- profile/avatar

Search field
"Kos dekat kampus atau area..."

Primary context
- campus
- current location optional

Recommended for you
- horizontal/vertical property cards

Near your campus
- compact list

Saved recently
- optional

Active tenancy
- muncul hanya bila ada
```

Jangan menaruh:

- 8 statistik;
- banner carousel promosi random;
- "AI Insights" card tanpa actionable value.

---

# 15. Property Card

Minimum:

```text
[Image]
Verified badge if applicable
Property name
Price / billing
Distance or travel time
Key facilities max 3
Verified rating
Match explanation badge
Availability
Favorite action
```

Match presentation:

```text
92% match
```

harus dilabeli sebagai skor kecocokan.

Alternative safer UI:

```text
Sangat cocok
```

with expandable "Kenapa direkomendasikan".

---

# 16. Recommendation Explanation

Bottom sheet:

```text
Kenapa kos ini cocok

✓ Masuk budget kamu
✓ 8 menit dari kampus
✓ WiFi dan kamar mandi dalam
✓ Keamanan sering mendapat feedback positif

Skor kecocokan bukan jaminan kualitas.
```

Jangan menampilkan formula kompleks di UI.

---

# 17. Explore Map

Map adalah full-screen canvas.

Overlay:

Top:

```text
[ Search area / campus ]
[ Filter ]
```

Bottom:

```text
Property preview bottom sheet
```

Marker:

- default marker bisa berupa price marker;
- selected marker memiliki state kuat;
- campus marker berbeda;
- current location marker standar.

Interactions:

- pan map;
- after significant move: show `Search this area`;
- tap marker: open preview;
- swipe preview cards: optionally sync marker;
- tap property: detail.

Jangan query server pada setiap frame pergerakan map.

---

# 18. Location Permission UX

Sebelum system permission, tampilkan pre-permission explanation:

```text
Temukan kos di sekitar kamu

Lokasi hanya digunakan saat kamu meminta pencarian "dekat saya".
KOSTARA tidak melakukan pelacakan lokasi di background.

[Nyalakan lokasi]
[Nanti saja]
```

Jika denied:

- jangan dead-end;
- arahkan ke campus/manual location.

---

# 19. Filter Sheet

Gunakan full-height/large bottom sheet.

Sections:

- harga;
- tipe kos;
- kamar;
- fasilitas;
- rating;
- availability;
- jarak;
- travel time jika tersedia.

Sticky footer:

```text
Reset          Tampilkan 42 kos
```

Jangan membuat 20 chip horizontal yang sulit dipindai.

---

# 20. Property Detail

Order:

1. immersive gallery;
2. name + verification + rating;
3. price + availability;
4. recommendation explanation;
5. distance/campus context;
6. available rooms;
7. key facilities;
8. map/location;
9. rules;
10. verified feedback;
11. owner identity/status;
12. sticky primary CTA.

Primary CTA:

- `Pilih kamar`
- atau `Ajukan minat`

tergantung product flow.

---

# 21. Room Detail

Tampilkan:

- room images;
- room code/type;
- price;
- deposit;
- size if known;
- facilities;
- availability;
- rules;
- request CTA.

Jangan duplicate seluruh property detail.

---

# 22. Compare Screen

Comparison maksimal 3.

Rows:

```text
Harga
Jarak
Travel time
Availability
Room type
WiFi
Bathroom
Parking
Security score
Internet feedback
Verified rating
Match score
```

Sticky action:

`Lihat pilihan terbaik untuk saya`

Action tersebut menjelaskan differences, bukan mendikte keputusan.

---

# 23. Saved Screen

Group:

- Available;
- No longer available;
- Recently updated.

Jika price/availability berubah, tandai:

```text
Harga diperbarui
Kamar penuh
Kamar tersedia lagi
```

---

# 24. Tenancy Home

Saat aktif:

```text
Property
Room
Tenancy period

Next payment
Amount
Due date
Status

Reminder
Payment history
Resident feedback
Owner contact info
```

Tone harus lebih administratif dan tenang daripada discovery.

---

# 25. Payment UX

Card utama:

```text
Jatuh tempo berikutnya
17 Oktober 2026

Rp950.000
Due in 6 days

[Atur pengingat]
[Lihat riwayat]
```

State:

- upcoming;
- due soon;
- paid;
- overdue;
- disputed if implemented later.

Jangan gunakan wording yang mengintimidasi user.

---

# 26. Reminder Setup

Simple checklist:

```text
7 hari sebelum
3 hari sebelum
1 hari sebelum
Hari H
Custom
```

Preview:

```text
Pengingat berikutnya:
14 Oktober, 09:00
```

---

# 27. Feedback UX

Eligibility state:

```text
Kamu sudah tinggal 30 hari.
Bagikan pengalaman untuk membantu penghuni berikutnya.
```

Aspect rating:

- cleanliness;
- security;
- internet;
- water;
- comfort;
- access;
- owner;
- value.

Free text optional tetapi dianjurkan.

Explain privacy:

`Review publik tidak menampilkan detail tenancy pribadi.`

---

# 28. Owner Home

Jangan membuat dashboard keuangan berat.

Top:

```text
Occupancy
Available rooms
Due soon
Needs attention
```

Then:

```text
Properties
Payment status
Recent tenancy requests
Resident feedback insights
```

Owner harus dapat menyelesaikan action penting dalam 1-2 tap.

---

# 29. Owner Property Management

Property list:

```text
Cover
Property name
Occupancy
Available rooms
Listing status
```

Property edit dibagi menjadi:

```text
Basic
Location
Rooms
Facilities
Photos
Rules
Publication
```

Gunakan save state yang jelas.

---

# 30. Pick Location

Map with draggable pin.

Actions:

```text
Gunakan lokasi saat ini
Cari alamat
Geser pin
Simpan lokasi
```

Show coordinate only in debug/advanced view, not primary UI.

---

# 31. Owner Feedback Insight

Tampilkan:

```text
Yang paling disukai
- Keamanan
- Kebersihan

Perlu perhatian
- Internet
- Parkir
```

Kemudian aspect breakdown.

Jangan menampilkan klaim yang tidak punya minimum review evidence.

Jika sample terlalu kecil:

`Belum cukup feedback untuk membuat ringkasan.`

---

# 32. Super Admin UX

Admin screens menekankan queue.

Example:

```text
Pending owner verification  12
Pending listing review       8
Reports                      5
```

Verification detail harus punya:

- evidence;
- listing/owner data;
- approve/reject;
- reason mandatory for rejection;
- audit trail.

---

# 33. Loading States

Gunakan skeleton untuk:

- home recommendation;
- property cards;
- detail;
- owner dashboard.

Map:

- show progress kecil untuk viewport search;
- jangan overlay full-screen loader setiap map movement.

---

# 34. Empty States

Empty state harus menjawab:

1. apa yang terjadi;
2. kenapa;
3. apa yang bisa dilakukan.

Contoh:

```text
Belum ada kos yang cocok dengan filter ini.

Coba perluas budget atau jarak pencarian.

[Ubah filter]
```

---

# 35. Error States

Harus dibedakan:

- no network;
- server error;
- permission denied;
- listing removed;
- location unavailable;
- ML unavailable.

ML unavailable:

```text
Rekomendasi personal sedang tidak tersedia.
Kami menampilkan pilihan berdasarkan preferensi kamu.
```

Jangan tampilkan generic `Something went wrong` untuk semua error.

---

# 36. Offline/Slow Network

- cache last viewed property;
- preserve saved local states until sync when safe;
- image progressive loading;
- map gracefully degrades;
- user input tidak hilang.

---

# 37. Accessibility

Minimum:

- 44-48dp touch targets;
- contrast;
- semantic label;
- support font scaling;
- no color-only state;
- clear focus/input label;
- map action punya list alternative.

---

# 38. Performance UX

Target principles:

- initial home tidak menunggu semua section;
- render above-the-fold dulu;
- lazy load images;
- pagination;
- marker clustering;
- debounced search;
- avoid huge blur effect;
- avoid heavy animation.

---

# 39. Mobile Layout Validation

Wajib diuji minimal:

```text
360x800
390x844
430x932
```

dan satu device Android kelas menengah jika tersedia.

Test:

- keyboard;
- long names;
- 200% text scale check;
- dark mode hanya jika V1 memutuskan mendukungnya.

Dark mode bukan blocker V1 kecuali dikunci sebagai requirement.

---

# 40. Content Style

Bahasa:

- singkat;
- manusiawi;
- langsung;
- tidak terlalu formal;
- tidak memakai jargon AI.

Prefer:

`Kenapa direkomendasikan`

bukan:

`AI Recommendation Explanation`

Prefer:

`Kos dekat kampus`

bukan:

`Geospatial Discovery Engine`

---

# 41. Design QA Checklist

Sebelum screen PASS:

- [ ] hierarchy jelas
- [ ] primary action hanya satu
- [ ] empty state
- [ ] loading state
- [ ] error state
- [ ] permission state bila ada
- [ ] accessible label
- [ ] small screen aman
- [ ] long text aman
- [ ] tidak ada overflow
- [ ] no unnecessary card nesting
- [ ] no emoji icons
- [ ] motion tidak menghambat
- [ ] sesuai role
- [ ] data state real, bukan placeholder final

---

# 42. Final Design Principle

KOSTARA harus terasa lebih pintar karena **hasilnya relevan**, bukan karena UI terus menerus mengatakan bahwa aplikasi menggunakan AI.
