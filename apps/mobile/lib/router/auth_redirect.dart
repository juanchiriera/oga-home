import 'package:oga/router/deep_link_contract.dart';

/// Router redirect inputs decoupled from Firebase for unit tests.
class AuthRedirectInput {
  const AuthRedirectInput({
    required this.matchedLocation,
    required this.uri,
    required this.isAuthReady,
    required this.isLoggedIn,
    this.takePendingDestination,
  });

  final String matchedLocation;
  final Uri uri;
  final bool isAuthReady;
  final bool isLoggedIn;
  final String? Function()? takePendingDestination;
}

/// Result of [resolveAuthRedirect]: `null` means no redirect.
String? resolveAuthRedirect(AuthRedirectInput input) {
  if (!input.isAuthReady) {
    return null;
  }

  final loc = input.matchedLocation;

  if (!input.isLoggedIn && loc != signInPath) {
    return signInPath;
  }
  if (input.isLoggedIn && loc == signInPath) {
    return input.takePendingDestination?.call() ?? '/app';
  }
  if (input.isLoggedIn && isFamilyEntityDeepLink(input.uri)) {
    return resolveFamilyEntityDestination(input.uri);
  }
  return null;
}
