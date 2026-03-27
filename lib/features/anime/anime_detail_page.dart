import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;
  const AnimeDetailPage({super.key, required this.animeId});

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  Map<String, dynamic>? _anime;
  bool _isLoading = true;
  bool _inMyList = false;
  int? _myRating;     // null = belum rating
  double _avgRating = 0;
  int _totalRatings = 0;
  bool _isSavingList = false;
  bool _isSavingRating = false;
  double _sliderVal = 7;

  String get _userId =>
      Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchAnime(),
        _fetchMyListStatus(),
        _fetchRatings(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnime() async {
    final data = await Supabase.instance.client
        .from('anime')
        .select()
        .eq('id', widget.animeId)
        .single();
    if (mounted) setState(() => _anime = data);
  }

  Future<void> _fetchMyListStatus() async {
    final data = await Supabase.instance.client
        .from('user_anime_list')
        .select('id')
        .eq('user_id', _userId)
        .eq('anime_id', widget.animeId);
    if (mounted) setState(() => _inMyList = (data as List).isNotEmpty);
  }

  Future<void> _fetchRatings() async {
    // Semua rating untuk anime ini
    final all = await Supabase.instance.client
        .from('ratings')
        .select('score, user_id')
        .eq('anime_id', widget.animeId);

    final list = all as List;
    double avg = 0;
    if (list.isNotEmpty) {
      avg = list.map((r) => r['score'] as int).reduce((a, b) => a + b) /
          list.length;
    }

    // Rating user ini
    final mine = list
        .where((r) => r['user_id'] == _userId)
        .toList();

    if (mounted) {
      setState(() {
        _avgRating = double.parse(avg.toStringAsFixed(1));
        _totalRatings = list.length;
        _myRating = mine.isNotEmpty ? mine.first['score'] as int : null;
        if (_myRating != null) _sliderVal = _myRating!.toDouble();
      });
    }
  }

  // ── Tambah / Hapus dari list ─────────────────────
  Future<void> _toggleList() async {
    setState(() => _isSavingList = true);
    try {
      if (_inMyList) {
        await Supabase.instance.client
            .from('user_anime_list')
            .delete()
            .eq('user_id', _userId)
            .eq('anime_id', widget.animeId);
        if (mounted) {
          setState(() => _inMyList = false);
          _showSnack('Dihapus dari list', isError: true);
        }
      } else {
        await Supabase.instance.client.from('user_anime_list').insert({
          'user_id': _userId,
          'anime_id': widget.animeId,
        });
        if (mounted) {
          setState(() => _inMyList = true);
          _showSnack('Ditambahkan ke list!');
        }
      }
    } catch (e) {
      _showSnack('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingList = false);
    }
  }

  // ── Submit rating ────────────────────────────────
  Future<void> _submitRating() async {
    final score = _sliderVal.round();
    setState(() => _isSavingRating = true);
    try {
      if (_myRating == null) {
        // Insert baru
        await Supabase.instance.client.from('ratings').insert({
          'user_id': _userId,
          'anime_id': widget.animeId,
          'score': score,
        });
      } else {
        // Update yang sudah ada
        await Supabase.instance.client.from('ratings').update({
          'score': score,
        })
            .eq('user_id', _userId)
            .eq('anime_id', widget.animeId);
      }
      await _fetchRatings();
      if (mounted) {
        _showSnack('Rating $score/10 disimpan!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Gagal simpan rating: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingRating = false);
    }
  }

  void _showRatingDialog() {
    _sliderVal = _myRating?.toDouble() ?? 7;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(
            _myRating == null ? 'Beri Rating' : 'Ubah Rating',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_sliderVal.round()} / 10',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _sliderVal,
                min: 1, max: 10, divisions: 9,
                activeColor: AppTheme.accent,
                inactiveColor: AppTheme.border,
                label: '${_sliderVal.round()}',
                onChanged: (v) {
                  setLocal(() => _sliderVal = v);
                  setState(() => _sliderVal = v);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('1', style: TextStyle(color: AppTheme.textMuted)),
                  Text('10', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: _isSavingRating ? null : _submitRating,
              child: _isSavingRating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_anime == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
            child: Text('Anime tidak ditemukan',
                style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final a = _anime!;
    final genres = (a['genres'] as List?)?.cast<String>() ?? [];
    final imageUrl = a['image_url'] as String?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar dengan gambar ─────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null && imageUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.surface)),
                        // Gradient overlay bawah
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.background,
                              ],
                              stops: [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: AppTheme.surface),
            ),
          ),

          // ── Konten ────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul
                      Text(
                        a['title'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Studio & Tahun
                      Row(
                        children: [
                          if (a['studio'] != null) ...[
                            const Icon(Icons.business_outlined,
                                size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(a['studio'],
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13)),
                            const SizedBox(width: 16),
                          ],
                          if (a['release_year'] != null) ...[
                            const Icon(Icons.calendar_today_outlined,
                                size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text('${a['release_year']}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13)),
                            const SizedBox(width: 16),
                          ],
                          if (a['episodes'] != null) ...[
                            const Icon(Icons.play_circle_outline,
                                size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text('${a['episodes']} ep',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 13)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status + Rating + Genre
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _Chip(
                            label: a['status'] == 'ongoing'
                                ? '● Ongoing'
                                : '✓ Completed',
                            color: a['status'] == 'ongoing'
                                ? AppTheme.success
                                : AppTheme.textSecondary,
                          ),
                          ...genres.map((g) =>
                              _Chip(label: g, color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Rating display
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: AppTheme.warning, size: 28),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _totalRatings == 0
                                      ? 'Belum ada rating'
                                      : '$_avgRating / 10',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_totalRatings > 0)
                                  Text(
                                    '$_totalRatings rating',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            if (_myRating != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AE50914),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Rating saya: $_myRating',
                                  style: const TextStyle(
                                      color: AppTheme.accent, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tombol aksi
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSavingList ? null : _toggleList,
                              icon: Icon(
                                _inMyList
                                    ? Icons.remove_circle_outline
                                    : Icons.add_circle_outline,
                              ),
                              label: Text(
                                _inMyList ? 'Hapus dari List' : 'Tambah ke List',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _inMyList
                                    ? AppTheme.surface
                                    : AppTheme.accent,
                                foregroundColor: _inMyList
                                    ? Colors.redAccent
                                    : Colors.white,
                                side: _inMyList
                                    ? const BorderSide(
                                        color: Colors.redAccent)
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showRatingDialog,
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: Text(
                                _myRating == null ? 'Beri Rating' : 'Edit Rating'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surface,
                              foregroundColor: AppTheme.warning,
                              side: const BorderSide(color: AppTheme.border),
                              minimumSize: const Size(0, 52),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Deskripsi
                      if (a['description'] != null &&
                          (a['description'] as String).isNotEmpty) ...[
                        const Text(
                          'Sinopsis',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a['description'],
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 12)),
      );
}
