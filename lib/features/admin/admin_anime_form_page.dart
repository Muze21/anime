import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class AdminAnimeFormPage extends StatefulWidget {
  final Map<String, dynamic>? anime;
  const AdminAnimeFormPage({super.key, this.anime});

  @override
  State<AdminAnimeFormPage> createState() => _AdminAnimeFormPageState();
}

class _AdminAnimeFormPageState extends State<AdminAnimeFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl    = TextEditingController();
  final _studioCtrl   = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _yearCtrl     = TextEditingController();
  final _episodesCtrl = TextEditingController();
  final _customGenreCtrl = TextEditingController();

  String _status = 'ongoing';
  List<String> _selectedGenres = [];
  bool _isSaving = false;

  // Image
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _existingImageUrl;

  static const List<String> _templateGenres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy',
    'Horror', 'Mystery', 'Romance', 'Sci-Fi', 'Slice of Life',
    'Sports', 'Supernatural', 'Thriller', 'Mecha',
    'Historical', 'Psychological', 'School', 'Isekai',
  ];

  bool get _isEditing => widget.anime != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final a = widget.anime!;
      _titleCtrl.text    = a['title'] ?? '';
      _studioCtrl.text   = a['studio'] ?? '';
      _descCtrl.text     = a['description'] ?? '';
      _yearCtrl.text     = (a['release_year'] ?? '').toString();
      _episodesCtrl.text = (a['episodes'] ?? '').toString();
      _status            = a['status'] ?? 'ongoing';
      _selectedGenres    = List<String>.from(a['genres'] ?? []);
      _existingImageUrl  = a['image_url'];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _studioCtrl.dispose(); _descCtrl.dispose();
    _yearCtrl.dispose();  _episodesCtrl.dispose(); _customGenreCtrl.dispose();
    super.dispose();
  }

  // ── Tambah genre
  void _addCustomGenre() {
    final g = _customGenreCtrl.text.trim();
    if (g.isEmpty) return;
    if (_selectedGenres.contains(g)) {
      _showError('"$g" sudah ada di list');
      return;
    }
    setState(() {
      _selectedGenres.add(g);
      _customGenreCtrl.clear();
    });
  }

  // ── Upload gambar
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageBytes   = result.files.first.bytes;
        _imageFileName = result.files.first.name;
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null || _imageFileName == null) return null;
    final ext  = _imageFileName!.split('.').last;
    final path = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    await Supabase.instance.client.storage
        .from('anime-images')
        .uploadBinary(path, _imageBytes!);
    return Supabase.instance.client.storage
        .from('anime-images')
        .getPublicUrl(path);
  }

  // ── nyimpen ke supabase
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenres.isEmpty) {
      _showError('Pilih atau masukkan minimal 1 genre');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_imageBytes != null) imageUrl = await _uploadImage();

      final data = {
        'title':        _titleCtrl.text.trim(),
        'studio':       _studioCtrl.text.trim(),
        'description':  _descCtrl.text.trim(),
        'release_year': int.tryParse(_yearCtrl.text.trim()),
        'episodes':     int.tryParse(_episodesCtrl.text.trim()),
        'status':       _status,
        'genres':       _selectedGenres,
        'image_url':    imageUrl,
      };

      if (_isEditing) {
        await Supabase.instance.client
            .from('anime').update(data).eq('id', widget.anime!['id']);
      } else {
        await Supabase.instance.client.from('anime').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Anime diperbarui' : 'Anime ditambahkan'),
          backgroundColor: AppTheme.success,
        ));
        context.pop();
      }
    } catch (e) {
      _showError('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }


  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Anime' : 'Tambah Anime'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
              child: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(_isEditing ? 'Simpan' : 'Tambah'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Gambar 
                  _sectionTitle('Gambar Anime'),
                  const SizedBox(height: 12),
                  _buildImageUploader(),
                  const SizedBox(height: 24),

                  // ── Info Dasar
                  _sectionTitle('Informasi Dasar'),
                  const SizedBox(height: 12),
                  _label('Judul *'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'Judul anime'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Judul wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Studio'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _studioCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'Nama studio'),
                  ),
                  const SizedBox(height: 16),

                  // Tahun | Episodes | Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Tahun Rilis'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _yearCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: 'cth: 2024'),
                              validator: (v) {
                                if (v != null && v.isNotEmpty) {
                                  final y = int.tryParse(v);
                                  if (y == null || y < 1900 || y > 2100) {
                                    return 'Tahun tidak valid';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Episode'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _episodesCtrl,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: 'cth: 12'),
                              validator: (v) {
                                if (v != null && v.isNotEmpty) {
                                  final ep = int.tryParse(v);
                                  if (ep == null || ep < 1) {
                                    return 'Episode tidak valid';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Status *'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _status,
                              dropdownColor: AppTheme.card,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: const InputDecoration(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'ongoing',
                                    child: Text('Ongoing')),
                                DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('Completed')),
                              ],
                              onChanged: (v) => setState(() => _status = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _label('Deskripsi'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText: 'Sinopsis anime...',
                        alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 28),

                  // ── Genre
                  _sectionTitle('Genre *'),
                  const SizedBox(height: 4),
                  const Text('Pilih dari template atau tambah kustom',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 14),

                  // Template genre chips
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _templateGenres.map((genre) {
                      final selected = _selectedGenres.contains(genre);
                      return FilterChip(
                        label: Text(genre),
                        selected: selected,
                        onSelected: (val) => setState(() {
                          if (val) {
                            _selectedGenres.add(genre);
                          } else {
                            _selectedGenres.remove(genre);
                          }
                        }),
                        backgroundColor: AppTheme.surface,
                        selectedColor: const Color(0x33E50914),
                        checkmarkColor: AppTheme.accent,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Input genre kustom
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Genre Kustom',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customGenreCtrl,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Ketik genre lalu tekan Tambah...',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addCustomGenre(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _addCustomGenre,
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 44)),
                              child: const Text('Tambah'),
                            ),
                          ],
                        ),

                        // Preview genre yang dipilih
                        if (_selectedGenres.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Genre dipilih:',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: _selectedGenres.map((g) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0x33E50914),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: AppTheme.accent),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(g,
                                        style: const TextStyle(
                                            color: AppTheme.accent,
                                            fontSize: 12)),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedGenres.remove(g)),
                                      child: const Icon(Icons.close,
                                          size: 14,
                                          color: AppTheme.accent),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Image uploader 
  Widget _buildImageUploader() {
    final hasNew = _imageBytes != null;
    final hasExisting = _existingImageUrl != null && !hasNew;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (hasNew || hasExisting)
                  ? AppTheme.accent
                  : AppTheme.border),
        ),
        child: hasNew
            ? _imageOverlay(Image.memory(_imageBytes!, fit: BoxFit.cover))
            : hasExisting
                ? _imageOverlay(Image.network(_existingImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _uploadHint()))
                : _uploadHint(),
      ),
    );
  }

  Widget _imageOverlay(Widget image) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(12), child: image),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Ganti',
                        style: TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _uploadHint() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined,
              size: 48, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text('Klik untuk upload gambar',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
          SizedBox(height: 4),
          Text('JPG, PNG, WEBP',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      );

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold));

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));
}
