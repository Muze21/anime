# 🎌 Anime Tracker App

Aplikasi web untuk melacak dan mengelola daftar anime favorit. Dibangun menggunakan **Flutter Web** dan **Supabase** sebagai backend.

> **⚠️ Penting:** Sebelum menjalankan aplikasi, salin `lib/core/supabase_config.example.dart` menjadi `lib/core/supabase_config.dart` dan isi dengan kredensial Supabase milikmu.

---

## ✨ Fitur Utama

### Untuk Pengguna
- 🔐 **Autentikasi** — Register dan login menggunakan email & password
- 🏠 **Halaman Home** — Tampilan semua anime dengan Hot Anime (Top 3 rating), pencarian, filter genre & status, dan sorting
- 📋 **My List** — Simpan anime yang ingin/sedang/sudah ditonton
- ⭐ **Rating** — Beri rating 1–10 untuk setiap anime
- 👍 **Like/Dislike** — Voting pada setiap anime
- 💬 **Komentar Real-Time** — Komentar dan reply langsung muncul tanpa reload halaman
- 🏆 **Top Anime** — Peringkat anime berdasarkan rating komunitas
- 👤 **Profil** — Ubah username dan foto profil

### Untuk Admin
- 📊 **Dashboard** — Statistik lengkap: total anime, user, rating, komentar, user banned
- 🎬 **Kelola Anime** — Tambah, edit, hapus anime beserta upload gambar
- 👥 **Kelola User** — Lihat daftar user, ban/unban dengan alasan
- 📈 **Analitik** — Top anime paling banyak di-list, di-rating, rating tertinggi, dan user paling aktif
- 📋 **Log Aktivitas** — Pantau 15 aktivitas terbaru di seluruh platform

---

## 🛠️ Teknologi

| Teknologi | Kegunaan |
|---|---|
| **Flutter** | Framework UI (Web) |
| **Dart** | Bahasa pemrograman |
| **Supabase** | Database, Auth, Storage, Realtime |
| **go_router** | Navigasi antar halaman |
| **cached_network_image** | Cache gambar dari URL |
| **intl** | Format tanggal & waktu |
| **file_picker** | Upload gambar profil & cover anime |

---

## 📁 Struktur Folder

```
lib/
├── main.dart                        # Entry point aplikasi
├── core/
│   ├── app_router.dart              # Konfigurasi routing & redirect (ban check)
│   ├── supabase_config.dart         # Kredensial Supabase (tidak di-upload ke GitHub)
│   └── theme.dart                   # Tema & warna global aplikasi
├── features/
│   ├── auth/
│   │   ├── login_page.dart          # Halaman login
│   │   └── register_page.dart       # Halaman registrasi
│   ├── home/
│   │   └── home_page.dart           # Halaman utama (Hot Anime, filter, grid)
│   ├── anime/
│   │   └── anime_detail_page.dart   # Detail anime, rating, like, komentar realtime
│   ├── mylist/
│   │   └── my_list_page.dart        # Daftar anime user
│   ├── recommendations/
│   │   └── recommendations_page.dart # Peringkat Top Anime
│   ├── profile/
│   │   └── profile_page.dart        # Profil user, ganti foto & username
│   ├── admin/
│   │   ├── admin_dashboard_page.dart # Dashboard admin & analitik
│   │   ├── admin_anime_list_page.dart# Kelola daftar anime
│   │   ├── admin_anime_form_page.dart# Form tambah/edit anime
│   │   └── admin_users_page.dart     # Kelola user & ban
│   └── shell/
│       └── user_shell.dart           # Bottom navigation bar
└── widgets/
    └── anime_card.dart               # Reusable widget kartu anime
```

---

## 🗄️ Skema Database (Supabase)

| Tabel | Kolom Utama | Keterangan |
|---|---|---|
| `anime` | id, title, studio, genres[], image_url, status, release_year, episodes, description | Data utama anime |
| `profiles` | id, username, email, avatar_url, role, is_banned, ban_reason | Data profil user |
| `user_anime_list` | user_id, anime_id | Anime yang disimpan user |
| `ratings` | user_id, anime_id, score | Rating 1–10 per user per anime |
| `anime_comments` | id, user_id, anime_id, content, parent_id, created_at | Komentar & reply |
| `anime_likes` | user_id, anime_id, type | Like/dislike per user per anime |

---

## ⚙️ Cara Setup & Menjalankan

### Prasyarat
- Flutter SDK (≥ 3.x)
- Akun [Supabase](https://supabase.com)
- Browser Chrome (untuk Flutter Web)

### Langkah Instalasi

**1. Clone repository**
```bash
git clone https://github.com/Muze21/anime.git
cd anime
```

**2. Install dependencies**
```bash
flutter pub get
```

**3. Setup Supabase**

Buat file `lib/core/supabase_config.dart` dengan isi berikut:
```dart
const String supabaseUrl = 'URL_SUPABASE_KAMU';
const String supabaseAnonKey = 'ANON_KEY_SUPABASE_KAMU';
```

URL dan Anon Key bisa didapatkan dari:
`Supabase Dashboard → Project Settings → API`

**4. Setup Database**

Jalankan SQL berikut di Supabase SQL Editor secara berurutan:

```sql
-- Tabel profiles (otomatis dibuat saat user register)
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text,
  username text,
  avatar_url text,
  role text default 'user',
  is_banned boolean default false,
  ban_reason text,
  created_at timestamptz default now()
);

-- Tabel anime
create table anime (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  studio text,
  description text,
  genres text[],
  image_url text,
  status text default 'ongoing',
  release_year int,
  episodes int,
  created_at timestamptz default now()
);

-- Tabel simpan list anime user
create table user_anime_list (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  anime_id uuid references anime on delete cascade,
  created_at timestamptz default now(),
  unique(user_id, anime_id)
);

-- Tabel rating
create table ratings (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  anime_id uuid references anime on delete cascade,
  score int check (score >= 1 and score <= 10),
  created_at timestamptz default now(),
  unique(user_id, anime_id)
);

-- Tabel komentar (support reply dengan parent_id)
create table anime_comments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  anime_id uuid references anime on delete cascade,
  parent_id uuid references anime_comments(id) on delete cascade,
  content text not null,
  created_at timestamptz default now()
);

-- Foreign key komentar ke profiles (untuk join data profil)
alter table anime_comments
  add constraint fk_anime_comments_profiles
  foreign key (user_id) references profiles(id);

-- Tabel like/dislike
create table anime_likes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade,
  anime_id uuid references anime on delete cascade,
  type text check (type in ('like', 'dislike')),
  created_at timestamptz default now(),
  unique(user_id, anime_id)
);
```

**5. Setup RLS (Row Level Security)**

```sql
-- Aktifkan RLS pada semua tabel
alter table profiles enable row level security;
alter table anime enable row level security;
alter table user_anime_list enable row level security;
alter table ratings enable row level security;
alter table anime_comments enable row level security;
alter table anime_likes enable row level security;

-- Profiles: siapapun bisa baca, hanya diri sendiri yang bisa update
create policy "Anyone can view profiles" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

-- Anime: siapapun bisa baca
create policy "Anyone can view anime" on anime for select using (true);

-- User anime list: hanya akses data sendiri
create policy "Users manage own list" on user_anime_list using (auth.uid() = user_id);

-- Ratings: siapapun bisa baca, hanya akses data sendiri untuk write
create policy "Anyone can view ratings" on ratings for select using (true);
create policy "Users manage own ratings" on ratings for insert with check (auth.uid() = user_id);
create policy "Users update own ratings" on ratings for update using (auth.uid() = user_id);

-- Komentar: siapapun bisa baca, hanya akses data sendiri untuk write
create policy "Anyone can view comments" on anime_comments for select using (true);
create policy "Users can insert comments" on anime_comments for insert with check (auth.uid() = user_id);
create policy "Users delete own comments" on anime_comments for delete using (auth.uid() = user_id);

-- Likes: siapapun bisa baca, hanya akses data sendiri untuk write
create policy "Anyone can view likes" on anime_likes for select using (true);
create policy "Users manage own likes" on anime_likes using (auth.uid() = user_id);
```

**6. Setup Storage (untuk upload gambar)**

Di Supabase Dashboard → Storage:
- Buat bucket baru bernama `anime-images` → centang **Public**
- Buat bucket baru bernama `avatars` → centang **Public**

**7. Jalankan aplikasi**
```bash
flutter run -d chrome
```

**8. Buat akun Admin**

Setelah mendaftar akun biasa, jalankan SQL berikut di Supabase untuk menjadikan akun tersebut admin:
```sql
update profiles set role = 'admin' where email = 'email_kamu@contoh.com';
```

---

## 🔐 Keamanan

- **Row Level Security (RLS)**: Setiap user hanya bisa membaca/mengubah data miliknya sendiri.
- **Ban System**: Admin dapat memblokir akun user. User yang di-ban akan otomatis di-logout saat berpindah halaman.
- **Unique Constraint**: Mencegah duplikasi data (misal: 1 user hanya bisa punya 1 rating per anime).
- **Kredensial**: File `supabase_config.dart` terdaftar di `.gitignore` sehingga API Key tidak ter-upload ke GitHub.

---

## 📌 Catatan Tambahan

- Fitur Hot Anime hanya muncul saat tidak ada filter aktif
- Komentar real-time menggunakan WebSocket (Supabase Realtime)
- Filter genre bersifat dinamis — genre baru dari database langsung muncul otomatis
- Halaman Top Anime menampilkan semua anime yang sudah pernah di-rating tanpa batas

---

## 👤 Developer

**Muze21** — [github.com/Muze21](https://github.com/Muze21)
