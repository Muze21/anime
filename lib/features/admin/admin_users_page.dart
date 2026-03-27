import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      // Ambil semua user beserta jumlah anime di list mereka
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*, user_anime_list(count)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack('Gagal memuat user: $e', isError: true);
    }
  }

  // ── Dialog BAN ──────────────────────────────────────
  Future<void> _showBanDialog(Map<String, dynamic> user) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(
          'Ban "${user['email']}"?',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan alasan ban (opsional):',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'cth: Melanggar peraturan komunitas...',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _updateBanStatus(
      user: user,
      isBanned: true,
      reason: reasonCtrl.text.trim(),
    );
    reasonCtrl.dispose();
  }

  // ── Dialog UNBAN ─────────────────────────────────────
  Future<void> _showUnbanDialog(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(
          'Unban "${user['email']}"?',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['ban_reason'] != null &&
                (user['ban_reason'] as String).isNotEmpty) ...[
              const Text('Alasan ban sebelumnya:',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x26FF5252),
                  borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: const Color(0x4DFF5252)),
                ),
                child: Text(
                  user['ban_reason'],
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text('Yakin ingin unban user ini?',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _updateBanStatus(user: user, isBanned: false, reason: '');
  }

  Future<void> _updateBanStatus({
    required Map<String, dynamic> user,
    required bool isBanned,
    required String reason,
  }) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_banned': isBanned,
        'ban_reason': isBanned ? reason : null,
      }).eq('id', user['id']);

      _fetchUsers();
      _showSnack(
        isBanned ? 'User berhasil di-ban' : 'User berhasil di-unban',
        isError: isBanned,
      );
    } catch (e) {
      _showSnack('Gagal update status: $e', isError: true);
    }
  }

  // ── Lihat list anime milik user ──────────────────────
  Future<void> _showUserAnimeList(Map<String, dynamic> user) async {
    showDialog(
      context: context,
      builder: (_) => _UserAnimeListDialog(
        userId: user['id'],
        userEmail: user['email'],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.redAccent : AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola User (${_users.length})'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchUsers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Text('Belum ada user',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _UserCard(
                    user: _users[i],
                    onBan: () => _showBanDialog(_users[i]),
                    onUnban: () => _showUnbanDialog(_users[i]),
                    onViewList: () => _showUserAnimeList(_users[i]),
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────
// User Card
// ─────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onViewList;

  const _UserCard({
    required this.user,
    required this.onBan,
    required this.onUnban,
    required this.onViewList,
  });

  @override
  Widget build(BuildContext context) {
    final isBanned = user['is_banned'] == true;
    final isAdmin = user['role'] == 'admin';
    final email = user['email'] ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    // Jumlah anime dari count
    final animeListData = user['user_anime_list'];
    int animeCount = 0;
    if (animeListData is List && animeListData.isNotEmpty) {
      animeCount = (animeListData[0]['count'] as int?) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBanned
              ? const Color(0x66FF5252)
              : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          // Baris atas: avatar + info + tombol aksi
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0x33E50914)
                      : AppTheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: isAdmin
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleBadge(role: user['role'] ?? 'user'),
                        if (isBanned) ...[
                          const SizedBox(width: 6),
                          const _BannedBadge(),
                        ],
                        const SizedBox(width: 8),
                        const Icon(Icons.movie_outlined,
                            size: 13, color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '$animeCount anime',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tombol aksi (hanya non-admin)
              if (!isAdmin) ...[
                IconButton(
                  tooltip: 'Lihat daftar anime',
                  icon: const Icon(Icons.list_alt_outlined,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: onViewList,
                ),
                isBanned
                    ? TextButton.icon(
                        onPressed: onUnban,
                        icon: const Icon(Icons.lock_open_outlined,
                            size: 16, color: AppTheme.success),
                        label: const Text('Unban',
                            style: TextStyle(
                                color: AppTheme.success, fontSize: 13)),
                      )
                    : TextButton.icon(
                        onPressed: onBan,
                        icon: const Icon(Icons.block,
                            size: 16, color: Colors.redAccent),
                        label: const Text('Ban',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
              ],
            ],
          ),

          // Alasan ban (jika ada)
          if (isBanned &&
              user['ban_reason'] != null &&
              (user['ban_reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x1AFF5252),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alasan: ${user['ban_reason']}',
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Dialog: List Anime User
// ─────────────────────────────────────────────────────
class _UserAnimeListDialog extends StatefulWidget {
  final String userId;
  final String userEmail;
  const _UserAnimeListDialog(
      {required this.userId, required this.userEmail});

  @override
  State<_UserAnimeListDialog> createState() => _UserAnimeListDialogState();
}

class _UserAnimeListDialogState extends State<_UserAnimeListDialog> {
  List<Map<String, dynamic>> _animeList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await Supabase.instance.client
          .from('user_anime_list')
          .select('added_at, anime(title, genres, status, image_url)')
          .eq('user_id', widget.userId)
          .order('added_at', ascending: false);

      if (mounted) {
        setState(() {
          _animeList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daftar Anime User',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(widget.userEmail,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    )
                  : _animeList.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'User belum menambahkan anime ke listnya.',
                            style: TextStyle(color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: _animeList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final entry = _animeList[i];
                            final anime = entry['anime'] as Map?;
                            final genres = (anime?['genres'] as List?)
                                    ?.cast<String>() ??
                                [];
                            final imageUrl =
                                anime?['image_url'] as String?;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: (imageUrl != null &&
                                            imageUrl.isNotEmpty)
                                        ? Image.network(imageUrl,
                                            width: 44,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _imgPlaceholder())
                                        : _imgPlaceholder(),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anime?['title'] ?? 'Unknown',
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(genres.take(2).join(', '),
                                            style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  _StatusBadge(
                                      status:
                                          anime?['status'] ?? ''),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 44,
        height: 56,
        color: AppTheme.card,
        child: const Icon(Icons.image_outlined,
            color: AppTheme.textMuted, size: 18),
      );
}

// ── Badge Widgets ────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? const Color(0x1AE50914)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color:
                isAdmin ? AppTheme.accent : AppTheme.border,
            width: 0.5),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
          color: isAdmin ? AppTheme.accent : AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BannedBadge extends StatelessWidget {
  const _BannedBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x26FF5252),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.redAccent, width: 0.5),
        ),
        child: const Text('Banned',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOngoing = status == 'ongoing';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOngoing
            ? const Color(0x1A4CAF50)
            : const Color(0x1A9E9E9E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOngoing ? 'Ongoing' : 'Completed',
        style: TextStyle(
          color: isOngoing ? AppTheme.success : AppTheme.textMuted,
          fontSize: 11,
        ),
      ),
    );
  }
}
