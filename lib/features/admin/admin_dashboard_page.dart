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
  int _animeCount = 0;
  int _userCount = 0;
  int _totalRatings = 0;
  int _bannedUsers = 0;
  String _topListedAnime = '—';
  String _topRatedAnime = '—';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final animeRes = await Supabase.instance.client
          .from('anime').select('id');
      final userRes = await Supabase.instance.client
          .from('profiles').select('id').neq('role', 'admin');
      final ratingRes = await Supabase.instance.client
          .from('ratings').select('anime_id');
      final bannedRes = await Supabase.instance.client
          .from('profiles').select('id').eq('is_banned', true);
      final listRes = await Supabase.instance.client
          .from('user_anime_list').select('anime_id, anime(title)');

      // Top anime by list count
      final listItems = listRes as List;
      final Map<String, int> listCount = {};
      final Map<String, String> listTitles = {};
      for (final item in listItems) {
        final id = item['anime_id'] as String;
        final title = (item['anime'] as Map?)?['title'] as String? ?? id;
        listCount[id] = (listCount[id] ?? 0) + 1;
        listTitles[id] = title;
      }
      String topListed = '—';
      if (listCount.isNotEmpty) {
        final topId = listCount.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;
        topListed = listTitles[topId] ?? '—';
      }

      // Top anime by rating count
      final ratingItems = ratingRes as List;
      final Map<String, int> ratingCount = {};
      for (final item in ratingItems) {
        final id = item['anime_id'] as String;
        ratingCount[id] = (ratingCount[id] ?? 0) + 1;
      }
      String topRated = '—';
      if (ratingCount.isNotEmpty) {
        final topId = ratingCount.entries
            .reduce((a, b) => a.value > b.value ? a : b).key;
        topRated = listTitles[topId] ?? topId;
      }

      if (mounted) {
        setState(() {
          _animeCount = (animeRes as List).length;
          _userCount = (userRes as List).length;
          _totalRatings = ratingItems.length;
          _bannedUsers = (bannedRes as List).length;
          _topListedAnime = topListed;
          _topRatedAnime = topRated;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        color: AppTheme.accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome Banner ──────────────────────
                    _WelcomeBanner(email: user?.email ?? ''),
                    const SizedBox(height: 28),

                    // ── Stats Row ───────────────────────────
                    Text(
                      'Statistik',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Row 1: Anime + User
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.movie_outlined,
                            label: 'Total Anime',
                            value: _isLoading ? '...' : '$_animeCount',
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.people_outline,
                            label: 'Total User',
                            value: _isLoading ? '...' : '$_userCount',
                            color: const Color(0xFF5C6BC0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Ratings + Banned
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.star_outline,
                            label: 'Total Rating',
                            value: _isLoading ? '...' : '$_totalRatings',
                            color: AppTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.block_outlined,
                            label: 'User Dibanned',
                            value: _isLoading ? '...' : '$_bannedUsers',
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Analytics Cards ─────────────────────
                    const Text(
                      'Analytics',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AnalyticsCard(
                      icon: Icons.bookmark_outlined,
                      label: 'Paling Banyak Dilist',
                      value: _isLoading ? '...' : _topListedAnime,
                      color: const Color(0xFF26A69A),
                    ),
                    const SizedBox(height: 10),
                    _AnalyticsCard(
                      icon: Icons.star_half_outlined,
                      label: 'Paling Banyak Dirating',
                      value: _isLoading ? '...' : _topRatedAnime,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(height: 28),

                    // ── Menu Grid (responsive) ───────────────
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuGrid(screenWidth),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(double screenWidth) {
    // 3 kolom untuk layar >= 900, 2 kolom untuk layar >= 600, 1 kolom lainnya
    final columns = screenWidth >= 900 ? 3 : (screenWidth >= 600 ? 2 : 1);

    final menus = [
      _MenuData(
        icon: Icons.movie_filter_outlined,
        title: 'Kelola Anime',
        subtitle: 'Tambah, edit, hapus anime',
        badge: '$_animeCount anime',
        onTap: () => context.go('/admin/anime'),
      ),
      _MenuData(
        icon: Icons.people_outline,
        title: 'Kelola User',
        subtitle: 'Lihat user, ban/unban',
        badge: '$_userCount user',
        onTap: () => context.go('/admin/users'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: screenWidth >= 600 ? 2.0 : 2.5,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) => _MenuCard(menu: menus[index]),
    );
  }
}

// ────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String email;
  const _WelcomeBanner({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accent, Color(0xFF7B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings,
              color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat datang, Admin!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color.fromARGB(38, color.r.toInt(), color.g.toInt(), color.b.toInt()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  _MenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuData menu;
  const _MenuCard({required this.menu});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: menu.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x1AE50914),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(menu.icon, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    menu.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    menu.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1AE50914),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                menu.badge,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Analytics Card ────────────────────────────────────
class _AnalyticsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AnalyticsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color.fromARGB(
                  38, color.r.toInt(), color.g.toInt(), color.b.toInt()),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
