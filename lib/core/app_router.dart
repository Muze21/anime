import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/shell/user_shell.dart';
import '../features/home/home_page.dart';
import '../features/anime/anime_detail_page.dart';
import '../features/mylist/my_list_page.dart';
import '../features/recommendations/recommendations_page.dart';
import '../features/profile/profile_page.dart';
import '../features/admin/admin_dashboard_page.dart';
import '../features/admin/admin_anime_list_page.dart';
import '../features/admin/admin_anime_form_page.dart';
import '../features/admin/admin_users_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isAuthPage =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!isLoggedIn && !isAuthPage) return '/login';
    if (!isLoggedIn) return null;

    // ban
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('is_banned, role')
          .eq('id', session.user.id)
          .single();

      if (profile['is_banned'] == true) {
        await Supabase.instance.client.auth.signOut();
        return '/login';
      }

      if (isAuthPage) {
        return profile['role'] == 'admin' ? '/admin' : '/home';
      }
    } catch (_) {}

    return null;
  },
  routes: [
    // ── Auth 
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    // ── Detail 
    GoRoute(
      path: '/detail/:id',
      builder: (context, state) {
        final animeId = state.pathParameters['id']!;
        return AnimeDetailPage(animeId: animeId);
      },
    ),

    // ── User
    ShellRoute(
      builder: (context, state, child) => UserShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/mylist',
          builder: (context, state) => const MyListPage(),
        ),
        GoRoute(
          path: '/recommendations',
          builder: (context, state) => const RecommendationsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),

    // ── Admin
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: '/admin/anime',
      builder: (context, state) => const AdminAnimeListPage(),
    ),
    GoRoute(
      path: '/admin/anime/add',
      builder: (context, state) => const AdminAnimeFormPage(),
    ),
    GoRoute(
      path: '/admin/anime/edit',
      builder: (context, state) {
        final anime = state.extra as Map<String, dynamic>;
        return AdminAnimeFormPage(anime: anime);
      },
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const AdminUsersPage(),
    ),
  ],
);
