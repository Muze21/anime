import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';

class AnimeCard extends StatelessWidget {
  final Map<String, dynamic> anime;
  final bool showRating;

  const AnimeCard({super.key, required this.anime, this.showRating = false});

  @override
  Widget build(BuildContext context) {
    final genres = (anime['genres'] as List?)?.cast<String>() ?? [];
    final imageUrl = anime['image_url'] as String?;
    final status = anime['status'] as String? ?? '';
    final avgRating = anime['avg_rating'];

    return GestureDetector(
      onTap: () => context.push('/detail/${anime['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Shimmer.fromColors(
                              baseColor: AppTheme.surface,
                              highlightColor: AppTheme.card,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: _StatusBadge(status: status),
                  ),
                  if (showRating && avgRating != null)
                    Positioned(
                      top: 8, right: 8,
                      child: _RatingBadge(rating: avgRating),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime['title'] ?? '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      genres.take(2).join(' · '),
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.surface,
        child: const Center(
          child: Icon(Icons.movie_outlined, color: AppTheme.textMuted, size: 32),
        ),
      );
}

/// Shimmer placeholder saat loading
class AnimeCardShimmer extends StatelessWidget {
  const AnimeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.card,
      highlightColor: AppTheme.surface,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 12, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 10, width: 80, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOngoing ? '● Ongoing' : '✓ Completed',
        style: TextStyle(
          color: isOngoing ? AppTheme.success : AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final dynamic rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: AppTheme.warning, size: 12),
          const SizedBox(width: 3),
          Text(
            '$rating',
            style: const TextStyle(
                color: AppTheme.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
