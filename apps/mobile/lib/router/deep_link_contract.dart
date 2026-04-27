const signInPath = '/sign-in';
const appPath = '/app';
const invitesPath = '/invites';

bool isFamilyEntityDeepLink(Uri uri) {
  final segments = uri.pathSegments;
  return segments.length == 4 &&
      segments[0] == 'family' &&
      segments[1].isNotEmpty &&
      segments[2].isNotEmpty &&
      segments[3].isNotEmpty;
}

String resolveFamilyEntityDestination(Uri uri) {
  if (!isFamilyEntityDeepLink(uri)) {
    return appPath;
  }

  final familyId = uri.pathSegments[1];
  final entityType = uri.pathSegments[2].toLowerCase();
  final entityId = uri.pathSegments[3];

  switch (entityType) {
    case 'home':
    case 'dashboard':
      return Uri(
        path: appPath,
        queryParameters: {'tab': 'home', 'familyId': familyId},
      ).toString();
    case 'stock':
    case 'stock-item':
    case 'stockitem':
      return Uri(
        path: appPath,
        queryParameters: {
          'tab': 'stock',
          'familyId': familyId,
          'entityType': entityType,
          'entityId': entityId,
        },
      ).toString();
    case 'invite':
    case 'invites':
      return Uri(
        path: invitesPath,
        queryParameters: {'familyId': familyId, 'entityId': entityId},
      ).toString();
    case 'recipe':
    case 'recipes':
      return Uri(
        path: '/app/recipes/$entityId',
        queryParameters: {'familyId': familyId},
      ).toString();
    default:
      return Uri(
        path: appPath,
        queryParameters: {
          'familyId': familyId,
          'entityType': entityType,
          'entityId': entityId,
        },
      ).toString();
  }
}

String? sanitizePendingDestination(String? raw) {
  if (raw == null || raw.trim().isEmpty || !raw.startsWith('/')) {
    return null;
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || uri.path.isEmpty || uri.path == signInPath) {
    return null;
  }

  return uri.toString();
}
