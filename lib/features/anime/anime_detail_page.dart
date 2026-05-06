import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class AnimeDetailPage extends StatefulWidget {
  final String animeId;
  const AnimeDetailPage({super.key, required this.animeId});
  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  final _supabase = Supabase.instance.client;
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  Map<String, dynamic>? _anime;
  bool _isLoading = true;
  bool _inMyList = false;
  int? _myRating;
  double _avgRating = 0;
  int _totalRatings = 0;
  bool _isSavingList = false;
  bool _isSavingRating = false;
  double _sliderVal = 7;

  // Like/Dislike
  String? _myVote;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _isVoting = false;

  // Comments
  List<Map<String, dynamic>> _comments = [];
  bool _isSendingComment = false;
  RealtimeChannel? _channel;

  // Reply
  String? _replyingToId;
  String? _replyingToName;

  String get _userId => _supabase.auth.currentUser!.id;
  String get _username => _supabase.auth.currentUser?.email?.split('@').first ?? 'User';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchAnime(),
        _fetchMyListStatus(),
        _fetchRatings(),
        _fetchLikes(),
        _fetchComments(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnime() async {
    final data = await _supabase.from('anime').select().eq('id', widget.animeId).single();
    if (mounted) setState(() => _anime = data);
  }

  Future<void> _fetchMyListStatus() async {
    final data = await _supabase.from('user_anime_list').select('id').eq('user_id', _userId).eq('anime_id', widget.animeId);
    if (mounted) setState(() => _inMyList = (data as List).isNotEmpty);
  }

  Future<void> _fetchRatings() async {
    final all = await _supabase.from('ratings').select('score, user_id').eq('anime_id', widget.animeId);
    final list = all as List;
    double avg = 0;
    if (list.isNotEmpty) avg = list.map((r) => r['score'] as int).reduce((a, b) => a + b) / list.length;
    final mine = list.where((r) => r['user_id'] == _userId).toList();
    if (mounted) setState(() {
      _avgRating = double.parse(avg.toStringAsFixed(1));
      _totalRatings = list.length;
      _myRating = mine.isNotEmpty ? mine.first['score'] as int : null;
      if (_myRating != null) _sliderVal = _myRating!.toDouble();
    });
  }

  Future<void> _fetchLikes() async {
    final data = await _supabase.from('anime_likes').select('user_id, type').eq('anime_id', widget.animeId);
    final list = data as List;
    final mine = list.where((r) => r['user_id'] == _userId).toList();
    if (mounted) setState(() {
      _likeCount = list.where((r) => r['type'] == 'like').length;
      _dislikeCount = list.where((r) => r['type'] == 'dislike').length;
      _myVote = mine.isNotEmpty ? mine.first['type'] as String : null;
    });
  }

  Future<void> _fetchComments() async {
    final data = await _supabase
        .from('anime_comments')
        .select('id, user_id, content, created_at, parent_id, profiles(username, avatar_url, email)')
        .eq('anime_id', widget.animeId)
        .order('created_at');
    if (mounted) setState(() => _comments = List<Map<String, dynamic>>.from(data));
  }

  void _subscribeComments() {
    _channel = _supabase
        .channel('comments:${widget.animeId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'anime_comments',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'anime_id', value: widget.animeId),
          callback: (payload) async {
            final newRow = payload.newRecord;
            // fetch profile for the new comment
            try {
              final profile = await _supabase.from('profiles').select('username, avatar_url, email').eq('id', newRow['user_id']).single();
              newRow['profiles'] = profile;
            } catch (_) {}
            if (mounted) {
              setState(() => _comments.add(Map<String, dynamic>.from(newRow)));
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _toggleVote(String type) async {
    if (_isVoting) return;
    setState(() => _isVoting = true);
    try {
      if (_myVote == type) {
        await _supabase.from('anime_likes').delete().eq('user_id', _userId).eq('anime_id', widget.animeId);
        setState(() {
          if (type == 'like') _likeCount = (_likeCount - 1).clamp(0, 999999); else _dislikeCount = (_dislikeCount - 1).clamp(0, 999999);
          _myVote = null;
        });
      } else {
        if (_myVote != null) {
          await _supabase.from('anime_likes').update({'type': type}).eq('user_id', _userId).eq('anime_id', widget.animeId);
          setState(() {
            if (_myVote == 'like') { _likeCount = (_likeCount - 1).clamp(0, 999999); _dislikeCount++; } else { _dislikeCount = (_dislikeCount - 1).clamp(0, 999999); _likeCount++; }
            _myVote = type;
          });
        } else {
          await _supabase.from('anime_likes').upsert({'user_id': _userId, 'anime_id': widget.animeId, 'type': type}, onConflict: 'user_id, anime_id');
          setState(() {
            if (type == 'like') _likeCount++; else _dislikeCount++;
            _myVote = type;
          });
        }
      }
    } catch (e) {
      _showSnack('Terjadi kesalahan sinkronisasi', isError: true);
      await _fetchLikes();
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSendingComment = true);
    try {
      final payload = {
        'user_id': _userId,
        'anime_id': widget.animeId,
        'content': text,
        if (_replyingToId != null) 'parent_id': _replyingToId,
      };
      await _supabase.from('anime_comments').insert(payload);
      _commentCtrl.clear();
      if (mounted) setState(() { _replyingToId = null; _replyingToName = null; });
    } catch (e) { _showSnack('Gagal kirim komentar: $e', isError: true); }
    finally { if (mounted) setState(() => _isSendingComment = false); }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _supabase.from('anime_comments').delete().eq('id', commentId);
      setState(() => _comments.removeWhere((c) => c['id'] == commentId));
    } catch (e) { _showSnack('Gagal hapus: $e', isError: true); }
  }

  Future<void> _toggleList() async {
    setState(() => _isSavingList = true);
    try {
      if (_inMyList) {
        await _supabase.from('user_anime_list').delete().eq('user_id', _userId).eq('anime_id', widget.animeId);
        if (mounted) { setState(() => _inMyList = false); _showSnack('Dihapus dari list', isError: true); }
      } else {
        await _supabase.from('user_anime_list').insert({'user_id': _userId, 'anime_id': widget.animeId});
        if (mounted) { setState(() => _inMyList = true); _showSnack('Ditambahkan ke list!'); }
      }
    } catch (e) { _showSnack('Gagal: $e', isError: true); }
    finally { if (mounted) setState(() => _isSavingList = false); }
  }

  Future<void> _submitRating() async {
    final score = _sliderVal.round();
    setState(() => _isSavingRating = true);
    try {
      if (_myRating == null) {
        await _supabase.from('ratings').insert({'user_id': _userId, 'anime_id': widget.animeId, 'score': score});
      } else {
        await _supabase.from('ratings').update({'score': score}).eq('user_id', _userId).eq('anime_id', widget.animeId);
      }
      await _fetchRatings();
      if (mounted) { _showSnack('Rating $score/10 disimpan!'); Navigator.pop(context); }
    } catch (e) { _showSnack('Gagal simpan rating: $e', isError: true); }
    finally { if (mounted) setState(() => _isSavingRating = false); }
  }

  void _showRatingDialog() {
    _sliderVal = _myRating?.toDouble() ?? 7;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(_myRating == null ? 'Beri Rating' : 'Ubah Rating', style: const TextStyle(color: AppTheme.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_sliderVal.round()} / 10', style: const TextStyle(color: AppTheme.accent, fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Slider(value: _sliderVal, min: 1, max: 10, divisions: 9, activeColor: AppTheme.accent, inactiveColor: AppTheme.border, label: '${_sliderVal.round()}', onChanged: (v) { setLocal(() => _sliderVal = v); setState(() => _sliderVal = v); }),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('1', style: TextStyle(color: AppTheme.textMuted)), Text('10', style: TextStyle(color: AppTheme.textMuted))]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(onPressed: _isSavingRating ? null : _submitRating, child: _isSavingRating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan')),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : AppTheme.success));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_anime == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Anime tidak ditemukan', style: TextStyle(color: AppTheme.textSecondary))));

    final a = _anime!;
    final genres = (a['genres'] as List?)?.cast<String>() ?? [];
    final imageUrl = a['image_url'] as String?;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null && imageUrl.isNotEmpty
                  ? Stack(fit: StackFit.expand, children: [
                      Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppTheme.surface)),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.background], stops: [0.5, 1.0]))),
                    ])
                  : Container(color: AppTheme.surface),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['title'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (a['studio'] != null) ...[const Icon(Icons.business_outlined, size: 14, color: AppTheme.textMuted), const SizedBox(width: 4), Text(a['studio'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)), const SizedBox(width: 16)],
                        if (a['release_year'] != null) ...[const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted), const SizedBox(width: 4), Text('${a['release_year']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)), const SizedBox(width: 16)],
                        if (a['episodes'] != null) ...[const Icon(Icons.play_circle_outline, size: 14, color: AppTheme.textMuted), const SizedBox(width: 4), Text('${a['episodes']} ep', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))],
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip(label: a['status'] == 'ongoing' ? '● Ongoing' : '✓ Completed', color: a['status'] == 'ongoing' ? AppTheme.success : AppTheme.textSecondary),
                        ...genres.map((g) => _Chip(label: g, color: AppTheme.textSecondary)),
                      ]),
                      const SizedBox(height: 16),

                      // Rating card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                        child: Row(children: [
                          const Icon(Icons.star, color: AppTheme.warning, size: 28),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_totalRatings == 0 ? 'Belum ada rating' : '$_avgRating / 10', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            if (_totalRatings > 0) Text('$_totalRatings rating', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ]),
                          const Spacer(),
                          if (_myRating != null) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0x1AE50914), borderRadius: BorderRadius.circular(8)),
                            child: Text('Rating saya: $_myRating', style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),

                      // Like/Dislike row
                      Row(children: [
                        _VoteButton(
                          icon: Icons.thumb_up_alt_rounded,
                          label: '$_likeCount',
                          active: _myVote == 'like',
                          activeColor: AppTheme.success,
                          onTap: () => _toggleVote('like'),
                        ),
                        const SizedBox(width: 10),
                        _VoteButton(
                          icon: Icons.thumb_down_alt_rounded,
                          label: '$_dislikeCount',
                          active: _myVote == 'dislike',
                          activeColor: Colors.redAccent,
                          onTap: () => _toggleVote('dislike'),
                        ),
                        const Spacer(),
                        Text('${_likeCount + _dislikeCount} votes', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ]),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSavingList ? null : _toggleList,
                            icon: Icon(_inMyList ? Icons.remove_circle_outline : Icons.add_circle_outline),
                            label: Text(_inMyList ? 'Hapus dari List' : 'Tambah ke List'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _inMyList ? AppTheme.surface : AppTheme.accent,
                              foregroundColor: _inMyList ? Colors.redAccent : Colors.white,
                              side: _inMyList ? const BorderSide(color: Colors.redAccent) : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showRatingDialog,
                          icon: const Icon(Icons.star_outline, size: 18),
                          label: Text(_myRating == null ? 'Beri Rating' : 'Edit Rating'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface, foregroundColor: AppTheme.warning, side: const BorderSide(color: AppTheme.border), minimumSize: const Size(0, 52)),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Sinopsis
                      if (a['description'] != null && (a['description'] as String).isNotEmpty) ...[
                        const Text('Sinopsis', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(a['description'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
                        const SizedBox(height: 24),
                      ],

                      // Comments section
                      Row(children: [
                        const Text('Komentar', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_comments.length}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Comment input
                      // Reply indicator
                      if (_replyingToId != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.reply, size: 14, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            Expanded(child: Text('Membalas @$_replyingToName', style: const TextStyle(color: AppTheme.accent, fontSize: 12))),
                            GestureDetector(
                              onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }),
                              child: const Icon(Icons.close, size: 14, color: AppTheme.accent),
                            ),
                          ]),
                        ),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                            decoration: InputDecoration(
                              hintText: 'Tulis komentar...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: ElevatedButton(
                            onPressed: _isSendingComment ? null : _sendComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              minimumSize: Size.zero,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSendingComment
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // Comment list
                      if (_comments.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Text('Belum ada komentar. Jadilah yang pertama! 👀', style: TextStyle(color: AppTheme.textMuted, fontSize: 13), textAlign: TextAlign.center),
                        )
                      else
                        ...() {
                          // Pisahkan top-level dan replies
                          final topLevel = _comments.where((c) => c['parent_id'] == null).toList();
                          final repliesMap = <String, List<Map<String, dynamic>>>{};
                          for (final c in _comments) {
                            final pid = c['parent_id'] as String?;
                            if (pid != null) {
                              repliesMap.putIfAbsent(pid, () => []);
                              repliesMap[pid]!.add(c);
                            }
                          }

                          Widget buildComment(Map<String, dynamic> c, {bool isReply = false}) {
                            final profile = c['profiles'] as Map?;
                            final uname = profile?['username'] as String?;
                            final email = profile?['email'] as String?;
                            final name = (uname != null && uname.isNotEmpty)
                                ? uname
                                : (email != null && email.contains('@'))
                                    ? email.split('@').first
                                    : 'Anonim';
                            final isOwn = c['user_id'] == _userId;
                            final dt = DateTime.tryParse(c['created_at'] ?? '');
                            final timeStr = dt != null ? DateFormat('dd MMM, HH:mm').format(dt.toLocal()) : '';
                            final replies = repliesMap[c['id']] ?? [];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: EdgeInsets.only(bottom: isReply ? 6 : 10, left: isReply ? 28 : 0),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isReply ? AppTheme.surface : AppTheme.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isOwn ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border),
                                  ),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (isReply) const Icon(Icons.subdirectory_arrow_right, size: 12, color: AppTheme.textMuted),
                                    if (isReply) const SizedBox(width: 4),
                                    CircleAvatar(
                                      radius: isReply ? 12 : 16,
                                      backgroundColor: AppTheme.card,
                                      backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url'] as String) : null,
                                      child: profile?['avatar_url'] == null ? Text(name[0].toUpperCase(), style: TextStyle(color: AppTheme.accent, fontSize: isReply ? 10 : 12, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text(name, style: TextStyle(color: isOwn ? AppTheme.accent : AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                        if (isOwn) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: const Text('Kamu', style: TextStyle(color: AppTheme.accent, fontSize: 9)))],
                                        const Spacer(),
                                        Text(timeStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(c['content'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        if (!isReply)
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _replyingToId = c['id'] as String;
                                                _replyingToName = name;
                                              });
                                              _commentCtrl.clear();
                                            },
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.reply, size: 12, color: AppTheme.textMuted),
                                              const SizedBox(width: 3),
                                              const Text('Balas', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                            ]),
                                          ),
                                        const Spacer(),
                                        if (isOwn)
                                          GestureDetector(
                                            onTap: () => _deleteComment(c['id'] as String),
                                            child: const Icon(Icons.delete_outline, size: 14, color: AppTheme.textMuted),
                                          ),
                                      ]),
                                    ])),
                                  ]),
                                ),
                                // Replies
                                ...replies.map((r) => buildComment(r, isReply: true)),
                              ],
                            );
                          }

                          return topLevel.map((c) => buildComment(c)).toList();
                        }(),
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

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _VoteButton({required this.icon, required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.15) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? activeColor : AppTheme.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: active ? activeColor : AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: active ? activeColor : AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
    child: Text(label, style: TextStyle(color: color, fontSize: 12)),
  );
}
