import 'package:oga/core/auth_session_gate.dart';
import 'package:oga/features/auth/sign_in_page.dart';
import 'package:oga/features/family/create_family_page.dart';
import 'package:oga/features/invite/invite_accept_page.dart';
import 'package:oga/features/invite/invites_list_page.dart';
import 'package:oga/features/profile/profile_page.dart';
import 'package:oga/features/recipes/recipes_page.dart';
import 'package:oga/features/shell/main_shell.dart';
import 'package:oga/router/auth_redirect.dart';
import 'package:oga/router/deep_link_contract.dart';
import 'package:oga/router/go_router_refresh.dart';
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

GoRouter buildAppRouter({
  FirebaseAuth? auth,
  AuthSessionGate? sessionGate,
}) {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  final gate = sessionGate;
  final pendingDestination = _PendingDestinationStore();
  final refreshSources = <Listenable>[
    GoRouterRefreshStream(firebaseAuth.authStateChanges()),
    ?gate,
  ];
  return GoRouter(
    initialLocation: '/app',
    refreshListenable: Listenable.merge(refreshSources),
    redirect: (context, state) {
      final isReady = gate?.isAuthReady ?? true;
      final loggedIn =
          gate?.isLoggedIn ?? firebaseAuth.currentUser != null;
      final destination = resolveAuthRedirect(
        AuthRedirectInput(
          matchedLocation: state.matchedLocation,
          uri: state.uri,
          isAuthReady: isReady,
          isLoggedIn: loggedIn,
          takePendingDestination: pendingDestination.take,
        ),
      );
      if (destination == signInPath) {
        pendingDestination.save(state.uri.toString());
      }
      return destination;
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
          openAssistantOnLaunch: MainShell.shouldOpenAssistantFromQuery(
            state.uri.queryParameters['tab'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'recipes/:recipeId',
            builder: (context, state) => RecipePreviewPage(
              recipeId: state.pathParameters['recipeId'] ?? '',
              familyId: state.uri.queryParameters['familyId'],
            ),
          ),
        ],
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
