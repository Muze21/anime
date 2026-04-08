import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../widgets/anime_card.dart';

enum _SortOption { newest, az, year, rating }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _allAnime = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _topAnime = [];
  List<String> _allGenres = [];

  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  String? _genreFilter;
  _SortOption _sort = _SortOption.newest;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final animeData = await Supabase.instance.client
          .from('anime').select().order('created_at', ascending: false);
      final ratingsData = await Supabase.instance.client
          .from('ratings').select('anime_id, score');

      final ratings = ratingsData as List;
      final allAnime = List<Map<String, dynamic>>.from(animeData);

      // Hitung avg rating per anime
      final Map<String, List<int>> grouped = {};
      for (final r in ratings) {
        final id = r['anime_id'] as String;
        grouped.putIfAbsent(id, () => []);
        grouped[id]!.add(r['score'] as int);
      }
      final enriched = allAnime.map((a) {
        final scores = grouped[a['id']];
        if (scores != null && scores.isNotEmpty) {
          return {
            ...a,
            'avg_rating':
                double.parse((scores.reduce((x, y) => x + y) / scores.length)
                    .toStringAsFixed(1)),
          };
        }
        return a;
      }).toList();

      // Kumpulkan semua genre unik
      final genreSet = <String>{};
      for (final a in enriched) {
        final genres = (a['genres'] as List?)?.cast<String>() ?? [];
        genreSet.addAll(genres);
      }

      // Top 3 by rating
      final withRating = enriched
          .where((a) => a['avg_rating'] != null)
          .toList()
        ..sort((a, b) => (b['avg_rating'] as double)
            .compareTo(a['avg_rating'] as double));

      if (mounted) {
        setState(() {
          _allAnime = enriched;
          _allGenres = genreSet.toList()..sort();
          _topAnime = withRating.take(3).toList();
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    var result = _allAnime.where((a) {
      final title = (a['title'] as String? ?? '').toLowerCase();
      final status = a['status'] as String? ?? '';
      final genres = (a['genres'] as List?)?.cast<String>() ?? [];

      final matchSearch =
          _search.isEmpty || title.contains(_search.toLowerCase());
      final matchStatus =
          _statusFilter == 'all' || status == _statusFilter;
      final matchGenre =
          _genreFilter == null || genres.contains(_genreFilter);

      return matchSearch && matchStatus && matchGenre;
    }).toList();

    // Sort
    switch (_sort) {
      case _SortOption.newest:
        result.sort((a, b) => (b['created_at'] as String)
            .compareTo(a['created_at'] as String));
      case _SortOption.az:
        result.sort((a, b) =>
            (a['title'] as String).compareTo(b['title'] as String));
      case _SortOption.year:
        result.sort((a, b) =>
            ((b['release_year'] as int?) ?? 0)
                .compareTo((a['release_year'] as int?) ?? 0));
      case _SortOption.rating:
        result.sort((a, b) =>
            ((b['avg_rating'] as double?) ?? 0)
                .compareTo((a['avg_rating'] as double?) ?? 0));
    }

    _filtered = result;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = v;
        _applyFilter();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxis = screenWidth > 1200 ? 5
        : screenWidth > 900 ? 4
        : screenWidth > 600 ? 3
        : 2;

    final isFiltering = _search.isNotEmpty ||
        _statusFilter != 'all' ||
        _genreFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Anime List'),
        actions: [
          // Sort button
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            color: AppTheme.card,
            tooltip: 'Urutkan',
            initialValue: _sort,
            onSelected: (v) => setState(() {
              _sort = v;
              _applyFilter();
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _SortOption.newest,
                child: Text('Terbaru'),
              ),
              PopupMenuItem(
                value: _SortOption.az,
                child: Text('A – Z'),
              ),
              PopupMenuItem(
                value: _SortOption.year,
                child: Text('Tahun Rilis'),
              ),
              PopupMenuItem(
                value: _SortOption.rating,
                child: Text('Rating Tertinggi'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        color: AppTheme.accent,
        child: CustomScrollView(
          slivers: [
            // ── Search ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari Anime Di Sini',
                    prefixIcon: const Icon(Icons.search,
                        color: AppTheme.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppTheme.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _search = '';
                                _applyFilter();
                              });
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            // ── Filter Status ─────────────────────
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _Chip(
                      label: 'Semua',
                      selected: _statusFilter == 'all' && _genreFilter == null,
                      onTap: () => setState(() {
                        _statusFilter = 'all';
                        _genreFilter = null;
                        _applyFilter();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Ongoing',
                      selected: _statusFilter == 'ongoing',
                      color: AppTheme.success,
                      onTap: () => setState(() {
                        _statusFilter = 'ongoing';
                        _applyFilter();
                      }),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Completed',
                      selected: _statusFilter == 'completed',
                      color: AppTheme.textSecondary,
                      onTap: () => setState(() {
                        _statusFilter = 'completed';
                        _applyFilter();
                      }),
                    ),
                    const SizedBox(width: 16),
                    // Divider visual
                    Container(
                        width: 1, height: 22, color: AppTheme.border),
                    const SizedBox(width: 16),
                    // Genre chips
                    ..._allGenres.map((g) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Chip(
                            label: g,
                            selected: _genreFilter == g,
                            color: const Color(0xFF7C4DFF),
                            onTap: () => setState(() {
                              _genreFilter = _genreFilter == g ? null : g;
                              _applyFilter();
                            }),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── Hot Anime (hanya saat tidak filter) ──
            if (!isFiltering && _topAnime.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          RichText(
                            text: const TextSpan(children: [
                              TextSpan(
                                text: 'Hot ',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: 'Anime',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 20),
                              ),
                            ]),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go('/recommendations'),
                            child: const Text('Lihat Peringkat >',
                                style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _HotAnimeLayout(topAnime: _topAnime),
                    ],
                  ),
                ),
              ),

            // ── Header grid ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  const Text('Semua Anime',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('${_filtered.length}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Grid ────────────────────────────
            if (_isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const AnimeCardShimmer(),
                    childCount: 10,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => AnimeCard(anime: _filtered[i]),
                    childCount: _filtered.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_filter_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              _search.isNotEmpty
                  ? 'Tidak ada hasil untuk "$_search"'
                  : 'Belum ada anime',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
// Hot Anime Section
// ─────────────────────────────────────────────
class _HotAnimeLayout extends StatelessWidget {
  final List<Map<String, dynamic>> topAnime;
  const _HotAnimeLayout({required this.topAnime});

  @override
  Widget build(BuildContext context) {
    final first = topAnime.isNotEmpty ? topAnime[0] : null;
    final second = topAnime.length > 1 ? topAnime[1] : null;
    final third = topAnime.length > 2 ? topAnime[2] : null;

    return SizedBox(
      height: 310,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (first != null)
            Expanded(
                flex: 5,
                child: _HotCard(anime: first, rank: 1, big: true)),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Column(children: [
              if (second != null)
                Expanded(child: _HotCard(anime: second, rank: 2)),
              if (second != null && third != null) const SizedBox(height: 10),
              if (third != null)
                Expanded(child: _HotCard(anime: third, rank: 3)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _HotCard extends StatelessWidget {
  final Map<String, dynamic> anime;
  final int rank;
  final bool big;
  const _HotCard({required this.anime, required this.rank, this.big = false});

  @override
  Widget build(BuildContext context) {
    final imageUrl = anime['image_url'] as String?;
    final avgRating = anime['avg_rating'];
    final episodes = anime['episodes'];

    return GestureDetector(
      onTap: () => context.push('/detail/${anime['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surface),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppTheme.surface),
                  )
                : Container(color: AppTheme.surface),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0,
              child: Container(
                width: big ? 42 : 32,
                height: big ? 42 : 32,
                color: AppTheme.warning,
                child: Center(
                  child: Text('#$rank',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: big ? 16 : 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            if (avgRating != null)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, color: AppTheme.warning, size: 12),
                    const SizedBox(width: 3),
                    Text('$avgRating',
                        style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (episodes != null)
                      Row(children: [
                        const Icon(Icons.play_circle_outline,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 3),
                        Text('Eps $episodes',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ]),
                    const SizedBox(height: 3),
                    Text(
                      anime['title'] ?? '',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: big ? 14 : 12,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Chip ──────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Color.fromARGB(38, c.r.toInt(), c.g.toInt(), c.b.toInt())
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? c : AppTheme.border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
