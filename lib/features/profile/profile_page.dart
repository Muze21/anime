import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  int _animeCount = 0;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;

  String get _userId =>
      Supabase.instance.client.auth.currentUser!.id;
  String get _userEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _userId)
          .single();

      final countData = await Supabase.instance.client
          .from('user_anime_list')
          .select('id')
          .eq('user_id', _userId);

      if (mounted) {
        setState(() {
          _profile = profileData as Map<String, dynamic>;
          _animeCount = (countData as List).length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Upload avatar ──────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final ext = file.name.split('.').last.toLowerCase();
      final path = '$_userId.$ext';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            path,
            file.bytes!,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/*'),
          );

      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      // Tambah cache-busting agar gambar refresh
      final bustedUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': bustedUrl}).eq('id', _userId);

      await _fetchProfile();
      if (mounted) {
        _showSnack('Foto profil berhasil diperbarui!');
      }
    } catch (e) {
      _showSnack('Gagal upload foto: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ── Ganti password ─────────────────────────────
  void _showChangePasswordDialog() {
    final newPwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text('Ganti Password',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPwCtrl,
                obscureText: obscure1,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Password baru',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure1
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () =>
                        setLocal(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure2,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Konfirmasi password baru',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppTheme.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure2
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () =>
                        setLocal(() => obscure2 = !obscure2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final pw = newPwCtrl.text.trim();
                      final cf = confirmCtrl.text.trim();
                      if (pw.isEmpty) {
                        _showSnack('Password tidak boleh kosong',
                            isError: true);
                        return;
                      }
                      if (pw.length < 6) {
                        _showSnack('Password minimal 6 karakter',
                            isError: true);
                        return;
                      }
                      if (pw != cf) {
                        _showSnack('Password tidak sama', isError: true);
                        return;
                      }
                      setLocal(() => isSaving = true);
                      try {
                        await Supabase.instance.client.auth
                            .updateUser(UserAttributes(password: pw));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack('Password berhasil diperbarui!');
                      } catch (e) {
                        _showSnack('Gagal: $e', isError: true);
                      } finally {
                        setLocal(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────
  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Keluar?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Yakin ingin keluar dari akun ini?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await Supabase.instance.client.auth.signOut();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final email = _userEmail;
    final initial =
        email.isNotEmpty ? email[0].toUpperCase() : '?';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final role = _profile?['role'] as String? ?? 'user';
    final createdAt = _profile?['created_at'] as String?;
    final joined = createdAt != null
        ? DateTime.tryParse(createdAt)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Avatar ────────────────────────
                        GestureDetector(
                          onTap: _isUploadingAvatar
                              ? null
                              : _pickAndUploadAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 54,
                                backgroundColor: AppTheme.surface,
                                backgroundImage: (avatarUrl != null &&
                                        avatarUrl.isNotEmpty)
                                    ? CachedNetworkImageProvider(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        initial,
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isUploadingAvatar
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                      : const Icon(Icons.camera_alt,
                                          color: Colors.white,
                                          size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Ketuk untuk ganti foto',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),

                        // ── Info ──────────────────────────
                        Text(
                          email,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Badge(
                                label: role == 'admin' ? 'Admin' : 'User',
                                color: role == 'admin'
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary),
                            if (joined != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                'Bergabung ${_formatDate(joined)}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 28),

                        // ── Stats Card ────────────────────
                        GestureDetector(
                          onTap: () => context.go('/mylist'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AE50914),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.bookmark,
                                      color: AppTheme.accent, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_animeCount Anime',
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Di list saya',
                                      style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.textMuted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Opsi ──────────────────────────
                        _OptionTile(
                          icon: Icons.lock_outline,
                          label: 'Ganti Password',
                          onTap: _showChangePasswordDialog,
                        ),
                        const SizedBox(height: 12),
                        _OptionTile(
                          icon: Icons.logout,
                          label: 'Keluar',
                          color: Colors.redAccent,
                          onTap: _showLogoutDialog,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Color.fromARGB(
              26, color.r.toInt(), color.g.toInt(), color.b.toInt()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _OptionTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(color: c, fontSize: 15)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
