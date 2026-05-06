import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;

  int _animeCount = 0;
  int _userCount = 0;
  int _ratingCount = 0;
  int _bannedCount = 0;
  int _commentCount = 0;
  bool _isLoading = true;

  List<Map<String, dynamic>> _topListed = [];
  List<Map<String, dynamic>> _topRatedByCount = [];
  List<Map<String, dynamic>> _highestRated = [];
  List<Map<String, dynamic>> _activeUsers = [];
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchStats(),
        _fetchTopListed(),
        _fetchTopRated(),
        _fetchActiveUsers(),
        _fetchRecentActivity(),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStats() async {
    final anime = await _supabase.from('anime').select('id');
    final users = await _supabase.from('profiles').select('id').neq('role', 'admin');
    final ratings = await _supabase.from('ratings').select('id');
    final banned = await _supabase.from('profiles').select('id').eq('is_banned', true);
    final comments = await _supabase.from('anime_comments').select('id');
    if (mounted) {
      _animeCount = (anime as List).length;
      _userCount = (users as List).length;
      _ratingCount = (ratings as List).length;
      _bannedCount = (banned as List).length;
      _commentCount = (comments as List).length;
    }
  }

  Future<void> _fetchTopListed() async {
    final data = await _supabase.from('user_anime_list').select('anime_id, anime(title, image_url)');
    final map = <String, Map<String, dynamic>>{};
    for (final row in data) {
      final aid = row['anime_id'] as String;
      map.putIfAbsent(aid, () => {'anime': row['anime'], 'count': 0});
      map[aid]!['count'] = (map[aid]!['count'] as int) + 1;
    }
    final sorted = map.values.toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (mounted) _topListed = sorted.take(5).toList();
  }

  Future<void> _fetchTopRated() async {
    final data = await _supabase.from('ratings').select('anime_id, score, anime(title, image_url)');
    final countMap = <String, Map<String, dynamic>>{};
    final scoreMap = <String, List<int>>{};
    for (final row in data) {
      final aid = row['anime_id'] as String;
      countMap.putIfAbsent(aid, () => {'anime': row['anime'], 'count': 0});
      countMap[aid]!['count'] = (countMap[aid]!['count'] as int) + 1;
      scoreMap.putIfAbsent(aid, () => []);
      scoreMap[aid]!.add(row['score'] as int);
    }
    // Top by count
    final byCount = countMap.entries.toList()..sort((a, b) => (b.value['count'] as int).compareTo(a.value['count'] as int));
    if (mounted) {
      _topRatedByCount = byCount.take(5).map((e) => {...e.value, 'anime_id': e.key}).toList();
    }
    // Highest avg (min 2 ratings)
    final avgList = <Map<String, dynamic>>[];
    for (final entry in scoreMap.entries) {
      if (entry.value.length >= 2) {
        final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        avgList.add({'anime': countMap[entry.key]!['anime'], 'avg': avg, 'count': entry.value.length});
      }
    }
    avgList.sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));
    if (mounted) _highestRated = avgList.take(5).toList();
  }

  Future<void> _fetchActiveUsers() async {
    final comments = await _supabase.from('anime_comments').select('user_id, profiles(username, email)');
    final ratings = await _supabase.from('ratings').select('user_id, profiles(username, email)');
    final map = <String, Map<String, dynamic>>{};
    for (final c in comments) {
      final uid = c['user_id'] as String;
      map.putIfAbsent(uid, () => {'profile': c['profiles'], 'comments': 0, 'ratings': 0});
      map[uid]!['comments'] = (map[uid]!['comments'] as int) + 1;
    }
    for (final r in ratings) {
      final uid = r['user_id'] as String;
      map.putIfAbsent(uid, () => {'profile': r['profiles'], 'comments': 0, 'ratings': 0});
      map[uid]!['ratings'] = (map[uid]!['ratings'] as int) + 1;
    }
    final sorted = map.values.toList()..sort((a, b) {
      final totalB = (b['comments'] as int) + (b['ratings'] as int);
      final totalA = (a['comments'] as int) + (a['ratings'] as int);
      return totalB.compareTo(totalA);
    });
    if (mounted) _activeUsers = sorted.take(5).toList();
  }

  Future<void> _fetchRecentActivity() async {
    final recentComments = await _supabase
        .from('anime_comments')
        .select('user_id, content, created_at, anime_id, profiles(username, email), anime(title)')
        .order('created_at', ascending: false)
        .limit(10);
    final recentRatings = await _supabase
        .from('ratings')
        .select('user_id, score, created_at, anime_id, profiles(username, email), anime(title)')
        .order('created_at', ascending: false)
        .limit(10);

    final activities = <Map<String, dynamic>>[];
    for (final c in recentComments) {
      activities.add({'type': 'comment', 'data': c, 'time': c['created_at']});
    }
    for (final r in recentRatings) {
      activities.add({'type': 'rating', 'data': r, 'time': r['created_at']});
    }
    activities.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));
    if (mounted) _recentActivity = activities.take(15).toList();
  }

  Future<void> _logout(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Keluar?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Yakin ingin keluar dari akun admin?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _supabase.auth.signOut();
    if (ctx.mounted) ctx.go('/login');
  }

  String _userName(Map? profile) {
    final u = profile?['username'] as String?;
    final e = profile?['email'] as String?;
    if (u != null && u.isNotEmpty) return u;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'Anonim';
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAll),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Keluar', onPressed: () => _logout(context)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        color: AppTheme.accent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WelcomeBanner(email: user?.email ?? ''),
                          const SizedBox(height: 28),
                          _sectionTitle('Statistik'),
                          const SizedBox(height: 12),
                          _buildStatsGrid(),
                          const SizedBox(height: 28),
                          _sectionTitle('Menu'),
                          const SizedBox(height: 12),
                          _buildMenuGrid(),
                          const SizedBox(height: 28),
                          _sectionTitle('Analitik'),
                          const SizedBox(height: 12),
                          _buildAnalytics(),
                          const SizedBox(height: 28),
                          _sectionTitle('Log Aktivitas Terbaru'),
                          const SizedBox(height: 12),
                          _buildActivityLog(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _buildStatsGrid() {
    final stats = [
      _StatData(Icons.movie_outlined, 'Total Anime', '$_animeCount', AppTheme.accent),
      _StatData(Icons.people_outline, 'Total User', '$_userCount', const Color(0xFF5C6BC0)),
      _StatData(Icons.star_outline, 'Total Rating', '$_ratingCount', const Color(0xFFFFA726)),
      _StatData(Icons.block_outlined, 'User Banned', '$_bannedCount', Colors.redAccent),
      _StatData(Icons.chat_bubble_outline, 'Total Komentar', '$_commentCount', const Color(0xFF26A69A)),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((s) => SizedBox(
        width: MediaQuery.of(context).size.width > 600 ? 200 : (MediaQuery.of(context).size.width - 52) / 2,
        child: _StatCard(icon: s.icon, label: s.label, value: s.value, color: s.color),
      )).toList(),
    );
  }

  Widget _buildMenuGrid() {
    final menus = [
      _MenuData(Icons.movie_filter_outlined, 'Kelola Anime', 'Tambah, edit, hapus anime', '$_animeCount anime', () => context.go('/admin/anime')),
      _MenuData(Icons.people_outline, 'Kelola User', 'Lihat user, ban/unban', '$_userCount user', () => context.go('/admin/users')),
    ];
    return Column(
      children: menus.map((m) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MenuCard(menu: m),
      )).toList(),
    );
  }

  Widget _buildAnalytics() {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 700;
    final children = [
      _AnalyticsCard(title: '🔥 Anime Paling Banyak di-List', items: _topListed.map((e) {
        final anime = e['anime'] as Map?;
        return _RankItem(anime?['title'] ?? '?', '${e['count']} user', anime?['image_url']);
      }).toList()),
      _AnalyticsCard(title: '⭐ Anime Paling Banyak di-Rating', items: _topRatedByCount.map((e) {
        final anime = e['anime'] as Map?;
        return _RankItem(anime?['title'] ?? '?', '${e['count']} rating', anime?['image_url']);
      }).toList()),
      _AnalyticsCard(title: '🏆 Anime Rating Tertinggi', items: _highestRated.map((e) {
        final anime = e['anime'] as Map?;
        final avg = (e['avg'] as double).toStringAsFixed(1);
        return _RankItem(anime?['title'] ?? '?', '⭐ $avg (${e['count']} vote)', anime?['image_url']);
      }).toList()),
      _AnalyticsCard(title: '👤 User Paling Aktif', items: _activeUsers.map((e) {
        final name = _userName(e['profile'] as Map?);
        final c = e['comments'] as int;
        final r = e['ratings'] as int;
        return _RankItem(name, '$c komen · $r rating', null);
      }).toList()),
    ];
    if (isWide) {
      return Wrap(spacing: 14, runSpacing: 14, children: children.map((c) => SizedBox(width: (screenW > 1100 ? 1060 : screenW - 40) / 2 - 7, child: c)).toList());
    }
    return Column(children: children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 14), child: c)).toList());
  }

  Widget _buildActivityLog() {
    if (_recentActivity.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: const Text('Belum ada aktivitas', style: TextStyle(color: AppTheme.textMuted), textAlign: TextAlign.center),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivity.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
        itemBuilder: (_, i) {
          final act = _recentActivity[i];
          final data = act['data'] as Map<String, dynamic>;
          final profile = data['profiles'] as Map?;
          final anime = data['anime'] as Map?;
          final name = _userName(profile);
          final animeName = anime?['title'] ?? '?';
          final dt = DateTime.tryParse(act['time'] ?? '');
          final timeStr = dt != null ? '${dt.toLocal().day}/${dt.toLocal().month} ${dt.toLocal().hour.toString().padLeft(2, '0')}:${dt.toLocal().minute.toString().padLeft(2, '0')}' : '';
          final isComment = act['type'] == 'comment';
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: isComment ? const Color(0x1A26A69A) : const Color(0x1AFFA726),
              child: Icon(isComment ? Icons.chat_bubble_outline : Icons.star_outline, size: 16, color: isComment ? const Color(0xFF26A69A) : const Color(0xFFFFA726)),
            ),
            title: RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary), children: [
              TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: isComment ? ' berkomentar di ' : ' memberi rating '),
              TextSpan(text: animeName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
              if (!isComment) TextSpan(text: ' (${data['score']}/10)'),
            ])),
            subtitle: isComment ? Text('"${(data['content'] as String? ?? '').length > 50 ? '${(data['content'] as String).substring(0, 50)}...' : data['content'] ?? ''}"', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)) : null,
            trailing: Text(timeStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          );
        },
      ),
    );
  }
}

// ── Data Classes ──
class _StatData {
  final IconData icon; final String label, value; final Color color;
  _StatData(this.icon, this.label, this.value, this.color);
}
class _MenuData {
  final IconData icon; final String title, subtitle, badge; final VoidCallback onTap;
  _MenuData(this.icon, this.title, this.subtitle, this.badge, this.onTap);
}
class _RankItem {
  final String title, subtitle; final String? imageUrl;
  _RankItem(this.title, this.subtitle, this.imageUrl);
}

// ── Welcome Banner ──
class _WelcomeBanner extends StatelessWidget {
  final String email;
  const _WelcomeBanner({required this.email});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.accent, Color(0xFF7B0000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Selamat datang, Admin!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Stat Card ──
class _StatCard extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])),
      ]),
    );
  }
}

// ── Menu Card ──
class _MenuCard extends StatelessWidget {
  final _MenuData menu;
  const _MenuCard({required this.menu});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: menu.onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0x1AE50914), borderRadius: BorderRadius.circular(10)),
            child: Icon(menu.icon, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(menu.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(menu.subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x1AE50914), borderRadius: BorderRadius.circular(8)),
            child: Text(menu.badge, style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
        ]),
      ),
    );
  }
}

// ── Analytics Card ──
class _AnalyticsCard extends StatelessWidget {
  final String title;
  final List<_RankItem> items;
  const _AnalyticsCard({required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1, color: AppTheme.border),
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada data', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))))
        else
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final medals = ['🥇', '🥈', '🥉'];
            final rank = i < 3 ? medals[i] : '${i + 1}.';
            return Column(children: [
              if (i > 0) const Divider(height: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 28, child: Text(rank, style: TextStyle(fontSize: i < 3 ? 18 : 14, color: AppTheme.textMuted))),
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(item.imageUrl!, width: 32, height: 42, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 32, height: 42, color: AppTheme.surface, child: const Icon(Icons.image, size: 14, color: AppTheme.textMuted))),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ])),
                ]),
              ),
            ]);
          }),
      ]),
    );
  }
}
