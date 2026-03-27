import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AdminAnimeListPage extends StatefulWidget {
  const AdminAnimeListPage({super.key});

  @override
  State<AdminAnimeListPage> createState() => _AdminAnimeListPageState();
}

class _AdminAnimeListPageState extends State<AdminAnimeListPage> {
  List<Map<String, dynamic>> _animeList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnime();
  }

  Future<void> _fetchAnime() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('anime')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _animeList = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Gagal memuat data: $e');
    }
  }

  Future<void> _deleteAnime(Map<String, dynamic> anime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Hapus Anime',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Yakin ingin menghapus "${anime['title']}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Hapus gambar dari storage jika ada
      final imageUrl = anime['image_url'] as String?;
      if (imageUrl != null && imageUrl.contains('anime-images')) {
        final uri = Uri.parse(imageUrl);
        final pathParts = uri.pathSegments;
        final storageIndex = pathParts.indexOf('anime-images');
        if (storageIndex != -1 && storageIndex + 1 < pathParts.length) {
          final filePath = pathParts.sublist(storageIndex + 1).join('/');
          await Supabase.instance.client.storage
              .from('anime-images')
              .remove([filePath]);
        }
      }

      await Supabase.instance.client
          .from('anime')
          .delete()
          .eq('id', anime['id']);

      _fetchAnime();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anime berhasil dihapus'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      _showError('Gagal menghapus: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Anime'),
        leading: BackButton(onPressed: () => context.go('/admin')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAnime,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.push('/admin/anime/add');
                _fetchAnime();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 40),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _animeList.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter_outlined,
              size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text('Belum ada anime',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/admin/anime/add');
              _fetchAnime();
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Anime Pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _animeList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final anime = _animeList[index];
        final genres = (anime['genres'] as List?)?.cast<String>() ?? [];
        final imageUrl = anime['image_url'] as String?;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              // Gambar
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime['title'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        genres.take(3).join(', '),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _StatusBadge(status: anime['status'] ?? ''),
                    ],
                  ),
                ),
              ),

              // Tombol aksi
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppTheme.textSecondary),
                    tooltip: 'Edit',
                    onPressed: () async {
                      await context.push('/admin/anime/edit', extra: anime);
                      _fetchAnime();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: 'Hapus',
                    onPressed: () => _deleteAnime(anime),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 100,
      color: AppTheme.surface,
      child: const Icon(Icons.image_outlined, color: AppTheme.textMuted),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOngoing = status == 'ongoing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOngoing
            ? const Color(0x1A4CAF50)
            : const Color(0x1A9E9E9E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOngoing ? AppTheme.success : AppTheme.textMuted,
          width: 0.5,
        ),
      ),
      child: Text(
        isOngoing ? 'Ongoing' : 'Completed',
        style: TextStyle(
          color: isOngoing ? AppTheme.success : AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
