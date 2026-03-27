import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Login via Supabase Auth
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user == null) {
        throw Exception('Login gagal. Cek email dan password.');
      }

      // Cek apakah user di-ban
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_banned, ban_reason, role')
          .eq('id', response.user!.id)
          .single();

      if (profile['is_banned'] == true) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          _showBanDialog(profile['ban_reason'] as String? ?? '');
        }
        return;
      }

      // Redirect berdasarkan role
      if (mounted) {
        if (profile['role'] == 'admin') {
          context.go('/admin');
        } else {
          context.go('/home');
        }
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e.message));
    } catch (e) {
      _showError('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Email atau password salah.';
    } else if (message.contains('Email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox Anda.';
    } else if (message.contains('Too many requests')) {
      return 'Terlalu banyak percobaan. Coba lagi nanti.';
    }
    return message;
  }

  // ── Popup ban ─────────────────────────────────
  void _showBanDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.block, color: Colors.redAccent, size: 48),
        title: const Text(
          'Akun Anda Di-ban',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Akun Anda telah dinonaktifkan oleh admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            if (reason.isNotEmpty) ...
              [
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF5252),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4DFF5252)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alasan:',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: 6),
            const Text(
              'Hubungi admin untuk informasi lebih lanjut.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(120, 42)),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ── Error snackbar (untuk error selain ban) ────
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / Header
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email
                        _buildLabel('Email'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'contoh@email.com',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: AppTheme.textMuted),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email wajib diisi';
                            if (!v.contains('@')) return 'Format email tidak valid';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
                        _buildLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Masukkan password',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textMuted,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password wajib diisi';
                            if (v.length < 6) return 'Password minimal 6 karakter';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Tombol Login
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Masuk'),
                        ),
                        const SizedBox(height: 24),

                        // Divider
                        const Row(
                          children: [
                            Expanded(child: Divider(color: AppTheme.border)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('atau',
                                  style:
                                      TextStyle(color: AppTheme.textMuted)),
                            ),
                            Expanded(child: Divider(color: AppTheme.border)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Daftar link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Belum punya akun? ',
                                style:
                                    TextStyle(color: AppTheme.textSecondary),
                              ),
                              TextButton(
                                onPressed: () => context.go('/register'),
                                child: const Text('Daftar sekarang'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x26E50914),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.play_circle_filled,
            color: AppTheme.accent,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Selamat Datang',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Masuk ke akun Anime Tracker Anda',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
