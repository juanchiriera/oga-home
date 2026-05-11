// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Oga - housekeeper';

  @override
  String get assistantTooltip => 'Assistant';

  @override
  String get navHome => 'Home';

  @override
  String get navStock => 'Stock';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get navNotes => 'Notes';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonContinue => 'Continue';

  @override
  String get signInBrand => 'Hearth & Habitat';

  @override
  String get signInWelcomeTitle => 'Welcome home';

  @override
  String get signInWelcomeSubtitle =>
      'Sign in with your account to coordinate your household.';

  @override
  String get signInAccessCardTitle => 'Household access';

  @override
  String get signInAccessCardDescription =>
      'Sync pantry, expenses, and notes with the people who share your home.';

  @override
  String get signInContinueWithGoogle => 'Continue with Google';

  @override
  String get signInJoinExistingHomeTitle => 'Join an existing home';

  @override
  String get signInJoinExistingHomeDescription =>
      'Have an invitation code? Redeem it here.';

  @override
  String get signInRedeemCode => 'Redeem code';

  @override
  String get signInFooterTagline => 'Sustainable living · Thoughtful design';

  @override
  String get inviteDialogTitle => 'Invitation code';

  @override
  String get inviteDialogHint => 'Paste the code or link';

  @override
  String get homeNoSession => 'No active session';

  @override
  String get homeProfileTooltip => 'Profile';

  @override
  String get homeSignOut => 'Sign out';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String homeGreetingLine(String greeting, String firstName) {
    return '$greeting, $firstName';
  }

  @override
  String get homeHeroSubtitleWithFamily =>
      'Here is a snapshot of your household: pantry, expenses, notes, and recipes in one place.';

  @override
  String get homeHeroSubtitleWithoutFamily =>
      'Create your household to coordinate pantry, expenses, and notes with the people you live with.';

  @override
  String get homeFamilyFallbackName => 'family';

  @override
  String get homeLoadingSandboxPlans => 'Loading sandbox plans...';

  @override
  String get homeFamilySpaceTitle => 'Your family space';

  @override
  String get homeFamilySpaceDescription =>
      'Create a household to share pantry, expenses, and notes.';

  @override
  String get homeCreateFamily => 'Create household';

  @override
  String get homeInvitations => 'Invitations';

  @override
  String get homeGenerateInvite => 'Generate invitation';

  @override
  String get inviteCreatedSheetTitle => 'Invitation ready';

  @override
  String get inviteCreatedSheetSubtitle =>
      'Share this link with the person you want to add to the household. You can also copy it or use the system share menu.';

  @override
  String inviteCreatedExpires(String date) {
    return 'Expires on $date';
  }

  @override
  String get inviteLinkCopy => 'Copy link';

  @override
  String get inviteLinkShare => 'Share';

  @override
  String get inviteCopiedToClipboard => 'Link copied';

  @override
  String get inviteCreateErrorPermissionDenied =>
      'You cannot create invitations: check that your subscription includes household invitations.';

  @override
  String inviteCreateErrorGeneric(String message) {
    return 'Could not create the invitation: $message';
  }

  @override
  String get invitesListTitle => 'Invitations';

  @override
  String get invitesEmptyTitle => 'No pending invitations';

  @override
  String get invitesEmptyDescription =>
      'Generate a link to invite someone to join this household.';

  @override
  String get invitesPendingIntro =>
      'Pending invitations to add members to the household.';

  @override
  String invitesExpiresLabel(String date) {
    return 'Expires: $date';
  }

  @override
  String get invitesNoSession => 'No active session';

  @override
  String get invitesNeedFamily => 'Create or join a household first.';

  @override
  String get homeActiveHousehold => 'Active household';

  @override
  String get homeMonthlyRecognizedExpense => 'Recognized expense this month';

  @override
  String get homeNoMonthlyMovements => 'No movements this month';

  @override
  String get homeScan => 'Scan';

  @override
  String get homeCategoriesWithMovement => 'Categories with movement';

  @override
  String get homeStockAlerts => 'Pantry alerts';

  @override
  String get homeNoStockAlerts => 'No items are marked as out or running low.';

  @override
  String homeStockAlertsToReview(int count, String suffix) {
    return '$count item$suffix to review.';
  }

  @override
  String get homeAllGoodForNow => 'Everything looks good for now.';

  @override
  String get homeUnnamedItem => '(unnamed)';

  @override
  String get homeViewFullPantry => 'View full pantry';

  @override
  String get homeRecentNote => 'Recent note';

  @override
  String get homeNoSharedNotesYet => 'There are no shared notes yet.';

  @override
  String get homeUntitledNote => '(untitled)';

  @override
  String get homeFeaturedRecipe => 'Featured recipe';

  @override
  String homeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String homeServings(int servings) {
    return '$servings servings';
  }

  @override
  String get revenueCatTitle => 'RevenueCat UI';

  @override
  String get revenueCatDescription =>
      'Paywall and customer center configured in RevenueCat.';

  @override
  String get revenueCatPaywall => 'Paywall';

  @override
  String get revenueCatOpenPaywallPayment => 'Pay subscription (sandbox)';

  @override
  String get revenueCatCustomerCenter => 'Customer center';

  @override
  String revenueCatPaywallError(String error) {
    return 'Paywall: $error';
  }

  @override
  String revenueCatCustomerCenterError(String error) {
    return 'Customer center: $error';
  }

  @override
  String get billingAvailableTitle => 'Premium plans available';

  @override
  String billingAvailableMessage(int packageCount) {
    return 'Found $packageCount package(s) in sandbox. You can validate purchases in the test environment.';
  }

  @override
  String get billingNotConfiguredTitle =>
      'Premium benefits are not available in this environment';

  @override
  String get billingNotConfiguredMessage =>
      'We are finishing subscription setup. You can keep using all base household features.';

  @override
  String get billingEmptyTitle => 'No plans available right now';

  @override
  String get billingEmptyMessage =>
      'There are no active offerings at the moment. Your current experience does not change, and you can try again in a few minutes.';

  @override
  String get billingErrorTitle => 'We could not load plans';

  @override
  String get billingErrorMessage =>
      'Check your connection and try again. In the meantime, you can keep managing your household normally.';

  @override
  String get billingRetry => 'Retry';

  @override
  String get billingRefreshPlans => 'Refresh plans';

  @override
  String get profileDeleteAccountSectionTitle => 'Danger zone';

  @override
  String get profileDeleteAccountDescription =>
      'Deleting your account removes your Firestore profile and takes you out of households (if you were the only person in a household, that household and its data are deleted). This action cannot be undone.';

  @override
  String get profileDeleteAccountWebLink => 'Request deletion from the web';

  @override
  String get profileDeleteAccountButton => 'Delete account';

  @override
  String get profileDeleteAccountConfirmTitle => 'Delete account?';

  @override
  String get profileDeleteAccountConfirmBody =>
      'Your cloud data and Firebase user will be deleted. You will need to sign in with Google again to confirm.';

  @override
  String get profileDeleteAccountConfirmAction => 'Delete permanently';

  @override
  String get profileDeleteAccountInProgress => 'Deleting account...';

  @override
  String get profileDeleteAccountCancelled => 'You cancelled Google sign-in.';

  @override
  String profileDeleteAccountError(String message) {
    return 'Could not delete the account: $message';
  }
}
