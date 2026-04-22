import 'package:craftr_mobile/features/auth/sign_in_page.dart';
import 'package:craftr_mobile/features/family/create_family_page.dart';
import 'package:craftr_mobile/features/invite/invite_accept_page.dart';
import 'package:craftr_mobile/features/invite/invites_list_page.dart';
import 'package:craftr_mobile/features/shell/main_shell.dart';
import 'package:craftr_mobile/router/go_router_refresh.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

GoRouter buildAppRouter() {
  final auth = FirebaseAuth.instance;
  return GoRouter(
    initialLocation: '/app',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;
      if (!loggedIn && loc != '/sign-in') {
        return '/sign-in';
      }
      if (loggedIn && loc == '/sign-in') {
        return '/app';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/create-family',
        builder: (context, state) => const CreateFamilyPage(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return InviteAcceptPage(token: token);
        },
      ),
      GoRoute(
        path: '/invites',
        builder: (context, state) => const InvitesListPage(),
      ),
    ],
  );
}
