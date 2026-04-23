import 'package:craftr_mobile/features/auth/sign_in_page.dart';
import 'package:craftr_mobile/features/family/create_family_page.dart';
import 'package:craftr_mobile/features/invite/invite_accept_page.dart';
import 'package:craftr_mobile/features/invite/invites_list_page.dart';
import 'package:craftr_mobile/features/profile/profile_page.dart';
import 'package:craftr_mobile/features/shell/main_shell.dart';
import 'package:craftr_mobile/router/deep_link_contract.dart';
import 'package:craftr_mobile/router/go_router_refresh.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class _PendingDestinationStore {
  String? _pending;

  void save(String? location) {
    _pending = sanitizePendingDestination(location);
  }

  String? take() {
    final current = _pending;
    _pending = null;
    return current;
  }
}

GoRouter buildAppRouter() {
  final auth = FirebaseAuth.instance;
  final pendingDestination = _PendingDestinationStore();
  return GoRouter(
    initialLocation: '/app',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;

      if (!loggedIn && loc != '/sign-in') {
        pendingDestination.save(state.uri.toString());
        return '/sign-in';
      }
      if (loggedIn && loc == '/sign-in') {
        return pendingDestination.take() ?? '/app';
      }
      if (loggedIn && isFamilyEntityDeepLink(state.uri)) {
        return resolveFamilyEntityDestination(state.uri);
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
        builder: (context, state) => MainShell(
          initialTab: MainShell.tabFromQuery(state.uri.queryParameters['tab']),
        ),
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
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/family/:familyId/:entityType/:entityId',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    ],
  );
}
