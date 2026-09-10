# Rencana Pengembangan Aplikasi Mobile SBPS — v3 (Perluasan & Penyempurnaan)

> **Menggantikan sebagian:** `Rencana_Pengembangan.md` (v2, 8 September 2026) — dokumen ini **tidak menghapus** isi v2, tapi menambahkan lapisan gap-analysis terhadap: (1) requirement operasional yang baru dikonfirmasi (kamera-only, watermark geotagging, offline-first menyeluruh, push notification wajib, dual device tablet+ponsel), dan (2) requirement backend `manual-book-development-multi-unit-bisnis-v6.md` Bagian 21 yang belum sepenuhnya tercermin di sisi mobile.
> **Sumber:** `SYSTEM_DOCUMENTATION.md` v2.0, `Rencana_Pengembangan.md` v2, `manual-book-development-multi-unit-bisnis-v6.md`.
> **Legenda status:** ✅ Selesai · 🟡 Sebagian · ⛔ Belum ada · ❓ Perlu audit/konfirmasi.

---

## 0. Ringkasan Temuan Utama

Setelah membandingkan 3 dokumen di atas, ditemukan **kesenjangan (gap) di 4 kategori besar**, plus **beberapa kontradiksi internal** di dokumentasi existing yang harus diselesaikan sebelum lanjut membangun fitur baru:

| # | Temuan | Tingkat urgensi |
|---|---|---|
| 1 | **Kunci kamera (no gallery) belum tersebut sama sekali** di `SYSTEM_DOCUMENTATION.md` — semua modul foto (Presensi, Formulir, Helper Armada, Upload generik, Checklist Armada) kemungkinan masih memakai image picker standar yang mengizinkan galeri | 🔴 Tinggi — ini syarat kredibilitas data lapangan |
| 2 | **Watermark visible (lat/lng/timestamp tercetak di foto) belum ada** — dokumentasi hanya menyebut GPS dikirim sebagai *metadata* terpisah (field `lat`, `lng` di body request), bukan dibakar ke pixel foto | 🔴 Tinggi |
| 3 | **Offline-first belum menyeluruh** — pola *outbox* baru diterapkan di endpoint tulis (write) tertentu; endpoint baca (GET: `titik-aktif`, `assignments`, `dashboard/*`, `master/*`, dll) tidak punya lapisan cache lokal yang jelas → di lokasi tanpa sinyal sama sekali, user tidak bisa membuka layar-layar itu | 🔴 Tinggi |
| 4 | **Push notification (FCM) masih ⛔** di sisi Flutter, hanya menunggu `google-services.json` — ini blocker administratif, bukan teknis, tapi User sudah menyatakan ini **wajib** | 🟠 Sedang-Tinggi (mudah diselesaikan) |
| 5 | **Kontradiksi status "Portal Kontraktor"** — §1 `Rencana_Pengembangan.md` bilang *"di-exclude sementara, belum digarap sisi Flutter"*, tapi §2 (tabel status) & §3.4 (backlog) bilang **✅ selesai penuh** dengan 2 screen terhubung. Ini harus diaudit langsung ke kode, jangan diasumsikan salah satu benar | ✅ **Sudah diaudit** — Portal Kontraktor SUDAH diimplementasi penuh (`role_permissions.dart`, `app_router.dart`, routes aktif) |
| 6 | **Inkonsistensi nama role**: `Driver Armada` (dipakai `armada/saya`, `armada/ritase`) vs `Driver Standby`/PIC Armada (dipakai checklist, ODO, helper, servis) — belum jelas apakah 1 role dengan 2 nama atau 2 role berbeda dari fase pengembangan berbeda | 🟠 Sedang — berisiko salah gating permission |
| 7 | **Inkonsistensi offline-flag di tabel endpoint (§26)**: `POST /armada/checklist` dan `POST /armada/odo-awal-proyek` **tidak** ditandai offline (✓) di tabel endpoint, padahal narasi status modul (§2/§3.4) menyebut keduanya sudah pakai outbox/idempotency. Perlu verifikasi kode aktual `ChecklistScreen`/`OdoAwalScreen` — apakah benar-benar antre ke outbox saat tanpa sinyal, atau saat ini gagal total | ✅ **Sudah diaudit** — Keduanya TIDAK pakai outbox, direct API call. Perlu perbaikan di Sprint 2 |
| 8 | **Background location tracking** masih foreground-only (`geolocator` saja, `flutter_background_service` ditunda) — kontradiktif dengan requirement backend 11.1 (interval tracking harus jalan sepanjang jam kerja walau app tidak dibuka) | 🟠 Sedang |
| 9 | Beberapa modul backend Bagian 21 **sengaja web-only** menurut manual book (Ritase 21.4, Sewa Eksternal 21.5, Role Inventory 21.7, Role Workshop 21.9, Checklist Major 21.10) — perlu **konfirmasi ulang** apakah keputusan "web-only" itu masih relevan mengingat jawaban Anda di poin 5 ("prioritas ke role yang butuh operasional detail di lapangan") | 🟡 Perlu keputusan Anda — lihat Bagian 6 |

Bagian-bagian berikut menjabarkan rencana penyelesaian tiap temuan di atas, plus perluasan fitur per modul.

---

## 1. Prasyarat — Audit Cepat Sebelum Sprint Dimulai (Sprint 0) ✅ SELESAI

> **Hasil audit diperbarui:** 10 September 2026

Jangan mulai membangun fitur baru sebelum 3 hal ini dikonfirmasi ke kode aktual (estimasi 2-3 hari kerja audit, bukan asumsi dari dokumen):

1. **Audit role**: buka seeder/migration role & permission di backend Laravel. Pastikan `Driver Armada` dan `Driver Standby` (atau PIC Armada) — satu role yang sama dengan alias, atau memang dua role. Dampak: kalau ternyata dua role berbeda, endpoint `armada/saya` & `armada/ritase` butuh guard tambahan yang belum ada di `app_router.dart`.
   - **Hasil audit:** Di sisi Flutter/client, role yang terdefinisi di `role_permissions.dart` hanya: `Mandor Titik`, `Kontraktor`, `Owner`, `Admin Keuangan`, `Driver Armada`, `Kepala Divisi Armada`. Tidak ada `Driver Standby` atau `PIC Armada` di kode client. Role dikirim ke backend via header `X-Active-Role` (stateless) — penamaan aktual bergantung pada seeder backend Laravel. **Status: perlu konfirmasi ke backend apakah ada role terpisah atau hanya alias.**
2. **Audit Portal Kontraktor**: jalankan aplikasi dengan akun role `Kontraktor`, cek langsung apakah `ProyekKontrakScreen` & `DetailProyekKontrakScreen` benar-benar ter-render dan terhubung ke 4 endpoint kontraktor, atau modul ini masih ter-*exclude* dari build (mis. route didaftarkan tapi tidak ada di menu navigasi Portal Proyek untuk role tsb).
   - **Hasil audit:** Portal Kontraktor **SUDAH diimplementasi** — `kProyekModules` di `role_permissions.dart` memasukkan modul `kontraktor`, route `/kontraktor/proyek` dan `/kontraktor/proyek/:id` terdaftar di `app_router.dart`, dan role `Kontraktor` mendapat akses `{'dashboard', 'kontraktor'}`. Klaim "belum digarap" di rencana v3 sebelumnya **salah**. Status: ✅ Selesai penuh.
3. **Audit offline flag armada**: uji manual `ChecklistScreen` dan `OdoAwalScreen` dalam mode airplane — apakah data masuk outbox (tersimpan di Hive, retry saat online), atau request langsung gagal/hilang. Ini krusial karena checklist harian & ODO adalah aktivitas yang **pasti** terjadi di lokasi tanpa sinyal (tambang/quarry).
   - **Hasil audit:** **TIDAK ADA outbox** untuk `POST /armada/checklist` dan `POST /armada/odo-awal-proyek` — `PendingEndpoint` enum di `pending_action.dart` hanya mencakup 9 endpoint (presensi, formulir, produksi, QC, upload, helperPresensi). Kedua screen tersebut (`ChecklistScreen` line 31, `OdoAwalScreen` line 67) memanggil `ArmadaRepository` langsung via `_api.post` tanpa fallback outbox. `helperPresensi` terdaftar di enum outbox tapi `HelperPresensiScreen` juga masih pakai direct call. **Status: ⛔ Perlu perbaikan di Sprint 2.**

---

## 2. Kebijakan Foto: Kamera-Only + Watermark Geotagging Wajib di Semua Modul

Ini requirement lintas-modul (bukan 1 fitur di 1 layar) — berlaku untuk: Presensi (check-in/out), Formulir Lapangan, Checklist Harian Armada, Presensi Helper, Servis Armada (foto kondisi), Upload dokumentasi generik.

### 2.1 Kunci kamera (disable gallery)
- Ganti seluruh pemanggilan `image_picker` yang masih memakai `ImageSource.gallery` menjadi **hanya** `ImageSource.camera`.
- Tambahkan pengecekan permission kamera eksplisit dengan pesan error yang jelas kalau ditolak user (bukan silent fail).
- Untuk Android, pastikan tidak ada jalur alternatif buka galeri lewat file picker sistem (`file_picker` full access) di modul manapun yang terkait dokumentasi foto lapangan — kalau ada kebutuhan upload dokumen non-foto (PDF nota servis dari Inventory misalnya, sesuai transkrip rapat 21.9), itu **boleh** dari file/galeri karena bukan bukti kondisi lapangan real-time — bedakan dua jenis upload ini secara eksplisit di UI (`UploadType.cameraOnly` vs `UploadType.anyFile`).
- Tambahkan flag ini sebagai parameter reusable di shared widget foto (`photo_capture_widget.dart` baru), supaya tidak perlu diimplementasi ulang di 6 modul berbeda.

### 2.2 Watermark visible (bukan cuma EXIF)
- Setelah foto diambil dari kamera dan sebelum kompresi (`photo_compression_service.dart`), tambahkan tahap **burn-in watermark** ke pixel gambar: teks lat/lng (format `-7.xxxxxx, 109.xxxxxx`), timestamp lokal (`dd/MM/yyyy HH:mm:ss`), dan opsional nama titik/nama karyawan — diposisikan di pojok bawah foto dengan background semi-transparan agar tetap terbaca di foto terang/gelap.
- Gunakan package image manipulation (`image` package Dart, karena sudah ada `flutter_image_compress` — kombinasikan: watermark dulu pakai `image` package, baru kompres) — tidak perlu library berbayar khusus watermark GPS.
- **Konten watermark (diputuskan):** koordinat + timestamp wajib di semua foto; **nama karyawan bersifat opsional per konteks** — tampilkan kalau data karyawan (dari `user.karyawan`/`user.name`) tersedia saat foto diambil, sembunyikan barisnya kalau tidak ada (jangan render baris kosong). Nama titik/proyek tidak wajib, bisa ditambahkan belakangan kalau dirasa perlu.
- **Fallback GPS gagal**: kalau GPS tidak dapat fix dalam beberapa detik, jangan blokir total pengambilan foto (bisa menghambat kerja), tapi watermark menampilkan status "Lokasi tidak tersedia" dan sistem menandai foto tsb `gps_status: unavailable` di metadata upload — supaya Mandor/reviewer tahu foto ini tidak tervalidasi lokasi, bukan dianggap seolah-olah valid.
- Terapkan ke **semua** titik pengambilan foto yang disebut di §1 atas (Presensi, Formulir, Checklist Armada, Helper, Servis Armada, Upload generik) — buat 1 widget `WatermarkedCameraCapture` yang dipakai ulang, jangan duplikasi logic.

### 2.3 Dampak ke backend
- Field `gps_status` (valid/unavailable) sebaiknya ikut dikirim di setiap endpoint upload foto supaya validasi radius (`ValidateLocationCheckInAction`, Bagian 6.2 manual book) punya konteks tambahan.
- Tidak ada perubahan skema besar di backend — watermark murni proses client-side sebelum file dikirim sebagai binary biasa.

---

## 3. Offline-First — Perluasan dari "Outbox untuk Tulis" ke "Cache untuk Baca + Outbox untuk Tulis"

Kondisi saat ini (dari `SYSTEM_DOCUMENTATION.md` §19 & §26): outbox pattern (Hive + retry backoff) sudah menutupi sebagian besar endpoint **POST**. Tapi requirement Anda ("semua fiturnya harus bisa offline karena terkadang di proyek tidak ada sinyal") berarti endpoint **GET** juga harus tetap bisa ditampilkan (dari cache terakhir) saat tidak ada sinyal sama sekali — bukan cuma "submit ditunda", tapi "buka aplikasi & lihat data tetap bisa" .

### 3.1 Read-cache layer (baru)
- Tambahkan lapisan cache Hive untuk semua response GET yang dipakai sebagai data kerja harian: `titik-aktif`, `titik-map`, `assignments`, `presensi/hari-ini`, `formulir/hari-ini`, `master/armada`, `armada/checklist-hari-ini`, `armada/helper`, `servis-armada` (list), `master/mesin`, `master/produk`, `master/bahan-baku`.
- Pola: *cache-first-then-refresh* — tampilkan data dari Hive langsung (instant, walau offline), lalu di background coba fetch terbaru dan update cache+UI kalau online. Tandai di UI kapan data terakhir disinkronkan ("Data per 08:42, offline").
- **Prioritas cache**: modul yang datanya dipakai untuk mengambil keputusan di lapangan (assignment titik kerja, checklist status hari ini, daftar armada & PIC) — bukan data historis besar seperti `dashboard/chart/*` yang bisa fallback ke pesan "Perlu koneksi untuk memuat grafik".

### 3.2 Perbaikan gap outbox armada (temuan #7)
- Audit ulang (lihat Sprint 0) — pastikan `POST /armada/checklist` dan `POST /armada/odo-awal-proyek` benar-benar masuk outbox kalau memang belum (perbaiki kalau ternyata masih direct-call tanpa fallback).
- Standarkan: **semua** endpoint POST yang bisa terjadi di lokasi tanpa sinyal (checklist, ODO, formulir, presensi, servis armada, upload foto, QC, produksi, tracking batch) **wajib** lewat outbox + idempotency key — tidak ada pengecualian.

### 3.3 Background location tracking (temuan #8)
- Implementasikan `flutter_background_service` untuk Mandor Titik agar interval GPS ping (Bagian 11.1 manual book — tiap 5-15 menit) tetap jalan walau app diminimize, selama masih dalam window `check_in`–`check_out`.
- Perlu foreground service notification (wajib Android 8+) — siapkan icon & teks singkat ("SBPS sedang merekam lokasi kerja").
- Auto-cutoff jam kerja default (misal 18:00) tetap diterapkan di sisi client sebagai safety net kalau lupa check-out, sesuai spek backend.
- Karena ini fitur yang tertunda karena kompleksitas battery/permission Android, sisihkan sprint terpisah (lihat roadmap §7) — jangan digabung dengan sprint watermark/kamera.

### 3.4 Testing wajib offline
Tambahkan checklist QA baru: uji setiap modul di atas dalam mode **airplane penuh** selama minimal 1 sesi kerja simulasi (check-in → isi checklist → isi formulir → check-out), baru nyalakan data dan pastikan semua data tersinkron tanpa duplikasi (cek idempotency key bekerja).

---

## 4. Push Notification (FCM) — Rencana Penyelesaian

Status: 🟡 backend siap, 🔴 Flutter menunggu file konfigurasi.

| Langkah | PIC | Catatan |
|---|---|---|
| 1. ~~Buat/hubungkan project Firebase untuk `com.sbps.mobile`~~ | — | ✅ **Sudah dibuat** — lanjut ke langkah 2 |
| 2. Download `google-services.json`, taruh di `android/app/` | Developer | Bisa langsung dieksekusi sekarang, tidak ada lagi blocker administratif |
| 3. Pastikan `PushTokenService` (sudah ada, 99 baris) dikoneksikan ulang — saat ini "aman kembalikan null sementara" | Developer | Perlu re-test setelah file terpasang |
| 4. Definisikan **tipe notifikasi** yang perlu dikirim backend (mapping ke Notification Center manual book Bagian 17.4): reminder formulir belum diisi, reminder servis butuh approval, reminder servis rutin (`ServiceDueReminderService`), reminder invoice jatuh tempo, reminder uji tekan QC | Anda + Developer | Backend perlu job/queue untuk trigger push per tipe ini — cek apakah sudah ada di Laravel Scheduler (`20.4`) |
| 5. Tentukan **deep-link** per tipe notifikasi (tap notifikasi → langsung ke layar terkait, misal tap "servis perlu approval" → `DetailServisScreen`) | Developer | |
| 6. Uji notifikasi saat app di background, foreground, dan killed state | QA | Ketiga state ini sering luput diuji |

---

## 5. Device & Responsive — Tablet Perusahaan + Ponsel Pribadi

Karena Anda konfirmasi kedua jenis device dipakai bersamaan (bukan salah satu saja):

- Audit `breakpoints.dart` (88 baris, sudah ada) — pastikan benar-benar men-generate layout berbeda untuk lebar layar tablet (≥600dp), bukan cuma stub kosong. Modul yang paling butuh optimasi tablet: **Dashboard** (grafik `fl_chart`), **Tracking** (peta `flutter_map`), **Armada Overview** — layar-layar ini padat informasi dan akan terasa sempit kalau dipaksa layout ponsel di tablet.
- Untuk modul input cepat di lapangan (Presensi, Checklist, Formulir) — layout ponsel yang sudah ada kemungkinan tetap oke dipakai di tablet (tidak perlu redesign besar), fokus optimasi ke layar yang sifatnya "monitoring/dashboard".
- Tambahkan uji manual di minimal 1 device tablet Android murah/mid-range (bukan cuma emulator) sebelum rilis, karena perusahaan tablet biasanya versi Android lebih lawas/RAM lebih kecil dari ponsel pribadi karyawan.

**Apakah jenis device (tablet vs ponsel) berpengaruh secara teknis?** Tidak signifikan untuk role Workshop maupun role lain — karena target platform tetap Android untuk keduanya, 1 codebase & 1 APK yang sama jalan di kedua jenis device (tidak perlu build terpisah). Pengaruhnya murni di sisi **pengalaman tampilan**: tablet punya layar lebih lega sehingga layout grid/dashboard bisa menampilkan lebih banyak informasi sekaligus, sementara di ponsel tetap harus ringkas per-scroll. Yang perlu diperhatikan hanya 2 hal teknis kecil: (1) resolusi kamera & kualitas GPS chip tablet murah kadang lebih rendah dari ponsel modern — pastikan proses watermark & validasi radius presensi tetap toleran terhadap itu; (2) tablet perusahaan biasanya versi Android lebih lawas — pastikan `minSdkVersion` app tetap mencakupnya. Selama dua hal ini diperhatikan, tidak perlu strategi pengembangan berbeda antara tablet dan ponsel.

---

## 6. Modul Backend Bagian 21 yang Masih "Web-Only" — Perlu Keputusan Anda

Manual book v6 secara eksplisit menandai beberapa fitur sebagai keputusan **web-only** (bukan karena belum sempat, tapi karena dianggap bukan use-case lapangan). Tapi jawaban Anda di poin 5 sebelumnya ("prioritaskan role yang butuh operasional detail") membuat sebagian ini layak dipertimbangkan ulang. Berikut rekomendasi saya per item — mohon konfirmasi mana yang mau dieksekusi ke mobile:

| Fitur | Status manual book | Keputusan | Alasan |
|---|---|---|---|
| **Ritase (jumlah trip & volume)** — 21.4 | Web-only (keputusan eksplisit) | ✅ **DIEKSEKUSI ke mobile** — input ringkas (jumlah rit + satuan) untuk Driver, sinkron ke web untuk verifikasi kantor | Driver dump truck ada di lapangan sepanjang hari — mencatat manual di kertas lalu diinput ulang di kantor rawan selisih |
| **Sewa Alat Eksternal** — 21.5 | Web-only | ✅ Tetap web-only (tidak diminta) | Transaksi non-proyek biasanya diinput admin/koordinator, bukan operator lapangan |
| **Role Inventory (stok opname, gudang)** — 21.7 | Web-only | ✅ Tetap web-only (tidak diminta) | Tidak termasuk dalam 3 item yang diminta dieksekusi |
| **Role Workshop — To-Do List & Riwayat Servis** — 21.9 | Web-only | ✅ **DIEKSEKUSI ke mobile** — teknisi workshop centang to-do (harian/mingguan) & upload foto hasil perbaikan dari lapangan/bengkel | Konsisten dengan prioritas ke role operasional lapangan |
| **Checklist Armada Major (serah terima sewa)** — 21.10 | Web-only | ✅ **DIEKSEKUSI ke mobile** untuk bagian "isi kondisi + foto" (cetak PDF tetap di web) | Serah terima fisik terjadi di lapangan, petugas jarang bawa laptop |
| **Monitoring Armada — metrik tambahan** — 21.11 | Belum ada bahkan di web (⛔) | Tunggu backend selesai dulu, baru rencanakan mobile view read-only | Backend prasyarat belum siap |

**Keputusan final:** Ritase, Workshop To-Do (+ Riwayat Servis), dan Checklist Major (bagian isi kondisi + foto) **langsung dieksekusi** ke roadmap mobile — masuk Sprint 5 (lihat Bagian 7, sekarang berstatus wajib, bukan opsional).

---

## 7. Roadmap Sprint (Revisi, Fokus Penyempurnaan)

**Catatan eksekusi:** semua sprint dikerjakan **berurutan** (bukan paralel), mengikuti kapasitas 1 developer — jangan mulai sprint berikutnya sebelum sprint sebelumnya selesai & lolos QA.

| Sprint | Fokus | Output |
|---|---|---|
| **Sprint 0** (2-3 hari) | Audit (lihat Bagian 1): role naming, status Portal Kontraktor, offline-flag armada | ✅ **SELESAI** — Role: 6 role terdefinisi di client (perlu konfirmasi backend). Portal Kontraktor: sudah implementasi. Offline armada: checklist & ODO belum pakai outbox (perlu perbaikan Sprint 2) |
| **Sprint 1** (1-2 minggu) | Kamera-only + watermark visible (koordinat + waktu wajib, nama karyawan opsional) — widget reusable, terapkan ke semua modul foto | ✅ **SELESAI** — Semua foto lapangan ber-watermark, galeri terkunci total. Widget `WatermarkedCameraCapture` reusable. 4 modul diupdate: Presensi, Formulir, Dokumentasi, Helper Presensi |
| **Sprint 2** (1-2 minggu) | Offline read-cache layer + perbaikan gap outbox armada (checklist, ODO) | ✅ **SELESAI** — Semua layar kerja harian bisa dibuka & submit tanpa sinyal. Outbox: `armadaChecklist`, `armadaOdoAwal`, `helperPresensi` ditambah ke PendingEndpoint. ArmadaRepository diupdate pakai outbox. CacheService baru dibuat untuk read-cache layer. |
| **Sprint 3** (1 minggu) | Push notification end-to-end (`google-services.json` tinggal dipasang → wiring backend trigger → deep link) | ✅ **SELESAI** — Firebase init dengan graceful degradation, PushTokenService, foreground handler, background handler, NotificationHandler untuk deep link (tap → navigate ke layar terkait). google-services.json sudah di repo. Backend trigger perlu di-setup di Laravel (job/queue). |
| **Sprint 4** (1 minggu) | Responsive tablet untuk Dashboard, Tracking, Armada Overview (1 codebase, layout adaptif) | UI nyaman dipakai tablet perusahaan maupun ponsel pribadi |
| **Sprint 5** (wajib — dikonfirmasi) | Ritase mobile ringkas + Workshop To-Do & Riwayat Servis mobile + Checklist Major (isi kondisi + foto) mobile | 3 modul baru live di mobile |
| **Sprint 6** (opsional, evaluasi kebutuhan) | Background location service penuh untuk Mandor Titik | Tracking interval jalan walau app di-minimize |

---

## 8. Checklist QA Sebelum Rilis (Tambahan Baru)

- [ ] Tidak ada satupun tombol/akses ke galeri di modul foto lapangan (uji tap semua ikon kamera)
- [ ] Watermark lat/lng/timestamp terbaca jelas di semua kondisi cahaya (uji outdoor siang terik & indoor gelap)
- [ ] Simulasi airplane mode penuh 1 siklus kerja (check-in → checklist → formulir → check-out → sync) tanpa kehilangan/duplikasi data
- [ ] Push notification diterima di 3 state app (foreground/background/killed) di device Android real (bukan cuma emulator)
- [ ] UI Dashboard/Tracking/Armada Overview diuji di tablet fisik, bukan cuma emulator
- [ ] Role `Kepala Divisi Armada`, `Driver Armada`/`Driver Standby` (setelah audit nama final), `Workshop` (kalau jadi dibangun) — masing-masing diuji login & menu sesuai role matrix final
- [ ] Idempotency: submit form yang sama 2x saat sinyal lemah tidak menghasilkan data ganda di backend

---

## 9. Keputusan Final (Terkonfirmasi)

Seluruh pertanyaan terbuka pada draft sebelumnya sudah dijawab dan diterapkan ke dokumen ini:

| # | Keputusan | Diterapkan di |
|---|---|---|
| 1 | Ritase mobile, Workshop To-Do mobile, dan Checklist Major mobile **langsung dieksekusi**, bukan opsional | Bagian 6, Sprint 5 |
| 2 | Project Firebase **sudah dibuat** — tinggal pasang `google-services.json` | Bagian 4, langkah 1-2 |
| 3 | Aplikasi dibuat **fleksibel untuk tablet & ponsel** (1 codebase Android, layout adaptif) — jenis device tidak memerlukan strategi pengembangan berbeda, hanya perlu perhatian di kualitas kamera/GPS device murah & `minSdkVersion` | Bagian 5 |
| 4 | Watermark foto: koordinat + waktu **wajib**, nama karyawan **opsional** (tampil kalau data tersedia, disembunyikan kalau tidak) | Bagian 2.2 |
| 5 | Semua sprint dieksekusi **berurutan**, tidak paralel | Bagian 7 |

Tidak ada lagi pertanyaan terbuka — dokumen ini siap dipakai sebagai acuan eksekusi mulai Sprint 0.