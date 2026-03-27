import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../widgets/anime_card.dart';

enum _SortMode { addedDate, ratingDesc, ratingAsc, az }

class MyListPage extends StatefulWidget {
  const MyListPage({super.key});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  List<Map<String, dynamic>> _anime = [];
  Map<String, int> _ratings = {};
  bool _isLoading = true;
  _SortMode _sort = _SortMode.addedDate;

  String get _userId =>
      Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final listRaw = await Supabase.instance.client
          .from('user_anime_list')
          .select('added_at, anime(*)')
          .eq('user_id', _userId)
          .order('added_at', ascending: false);

      final ratingRaw = await Supabase.instance.client
          .from('ratings')
          .select('anime_id, score')
          .eq('user_id', _userId);

      final ratingMap = <String, int>{};
      for (final r in ratingRaw as List) {
        ratingMap[r['anime_id'] as String] = r['score'] as int;
      }

      final items = (listRaw as List).map((item) {
        final a = Map<String, dynamic>.from(item['anime'] as Map);
        a['_added_at'] = item['added_at'];
        return a;
      }).toList();

      if (mounted) {
        setState(() {
          _anime = items;
          _ratings = ratingMap;
          _applySort();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySort() {
    switch (_sort) {
      case _SortMode.addedDate:
        _anime.sort((a, b) => (b['_added_at'] as String)
            .compareTo(a['_added_at'] as String));
      case _SortMode.ratingDesc:
        _anime.sort((a, b) {
          final ra = _ratings[a['id']] ?? 0;
          final rb = _ratings[b['id']] ?? 0;
          return rb.compareTo(ra);
        });
      case _SortMode.ratingAsc:
        _anime.sort((a, b) {
          final ra = _ratings[a['id']] ?? 0;
          final rb = _ratings[b['id']] ?? 0;
          return ra.compareTo(rb);
        });
      case _SortMode.az:
        _anime.sort((a, b) =>
            (a['title'] as String).compareTo(b['title'] as String));
    }
  }

  Future<void> _remove(String animeId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Hapus dari List?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Hapus "$title" dari list kamu?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await Supabase.instance.client
        .from('user_anime_list')
        .delete()
        .eq('user_id', _userId)
        .eq('anime_id', animeId);

    _fetch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$title" dihapus dari list'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxis =
        screenWidth > 900 ? 4 : screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text('My List (${_anime.length})'),
        actions: [
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            color: AppTheme.card,
            tooltip: 'Urutkan',
            initialValue: _sort,
            onSelected: (v) => setState(() {
              _sort = v;
              _applySort();
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _SortMode.addedDate,
                  child: Text('Terbaru Ditambah')),
              PopupMenuItem(
                  value: _SortMode.ratingDesc,
                  child: Text('Rating Terbaik')),
              PopupMenuItem(
                  value: _SortMode.ratingAsc,
                  child: Text('Rating Terburuk')),
              PopupMenuItem(
                  value: _SortMode.az, child: Text('A – Z')),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppTheme.accent,
        child: _isLoading
            ? GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.62,
                ),
                itemCount: 6,
                itemBuilder: (_, __) => const AnimeCardShimmer(),
              )
            : _anime.isEmpty
                ? _buildEmpty()
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxis,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: _anime.length,
                    itemBuilder: (_, i) {
                      final anime = _anime[i];
                      final myRating = _ratings[anime['id']];
                      return Stack(
                        children: [
                          AnimeCard(anime: anime),
                          // Rating badge pojok bawah kiri
                          if (myRating != null)
                            Positioned(
                              bottom: 44,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star,
                                        color: AppTheme.warning,
                                        size: 12),
                                    const SizedBox(width: 3),
                                    Text('$myRating/10',
                                        style: const TextStyle(
                                            color: AppTheme.warning,
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          // Tombol hapus ×
                          Positioned(
                            top: 6, right: 6,
                            child: GestureDetector(
                              onTap: () => _remove(
                                  anime['id'], anime['title'] ?? ''),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_border,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('List kamu masih kosong',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Tambah anime dari halaman Browse',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Browse Anime'),
              ),
            ),
          ],
        ),
      );
}
