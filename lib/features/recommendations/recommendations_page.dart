import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../widgets/anime_card.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  List<Map<String, dynamic>> _animeList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      // Ambil semua rating lalu hitung rata-rata di client
      // (Supabase JS SDK tidak support GROUP BY langsung —
      //  gunakan RPC untuk solusi production, ini cukup untuk dev)
      final ratingsRaw = await Supabase.instance.client
          .from('ratings')
          .select('anime_id, score');

      final animeRaw = await Supabase.instance.client
          .from('anime')
          .select();

      final ratings = ratingsRaw as List;
      final allAnime = animeRaw as List;

      // Hitung avg per anime_id
      final Map<String, List<int>> grouped = {};
      for (final r in ratings) {
        final id = r['anime_id'] as String;
        grouped.putIfAbsent(id, () => []);
        grouped[id]!.add(r['score'] as int);
      }

      final Map<String, double> avgMap = {};
      grouped.forEach((id, scores) {
        avgMap[id] = scores.reduce((a, b) => a + b) / scores.length;
      });

      // Gabungkan + urutkan
      final result = allAnime
          .where((a) => avgMap.containsKey(a['id']))
          .map((a) => {
                ...Map<String, dynamic>.from(a),
                'avg_rating':
                    double.parse(avgMap[a['id']]!.toStringAsFixed(1)),
                'total_ratings': grouped[a['id']]!.length,
              })
          .toList()
        ..sort((a, b) => (b['avg_rating'] as double)
            .compareTo(a['avg_rating'] as double));

      if (mounted) {
        setState(() {
          _animeList = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxis = screenWidth > 900 ? 4 : screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi'),
        leading: BackButton(onPressed: () => context.go('/home')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _animeList.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      color: AppTheme.surface,
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Top ${_animeList.length} anime berdasarkan rating komunitas',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(14),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxis,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: _animeList.length,
                        itemBuilder: (_, i) {
                          final anime = _animeList[i];
                          return Stack(
                            children: [
                              AnimeCard(
                                  anime: anime, showRating: true),
                              // Rank badge di pojok kiri bawah
                              Positioned(
                                bottom: 44,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: i < 3
                                        ? AppTheme.accent
                                        : Colors.black54,
                                    borderRadius:
                                        const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_border_outlined,
              size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Belum ada rekomendasi',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rekomendasi muncul setelah ada user yang memberi rating',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
