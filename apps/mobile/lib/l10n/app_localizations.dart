import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es', 'AR'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Oga - housekeeper'**
  String get appTitle;

  /// No description provided for @assistantTooltip.
  ///
  /// In es, this message translates to:
  /// **'Asistente'**
  String get assistantTooltip;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navStock.
  ///
  /// In es, this message translates to:
  /// **'Stock'**
  String get navStock;

  /// No description provided for @navExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get navExpenses;

  /// No description provided for @navRecipes.
  ///
  /// In es, this message translates to:
  /// **'Recetas'**
  String get navRecipes;

  /// No description provided for @navNotes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get navNotes;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @signInBrand.
  ///
  /// In es, this message translates to:
  /// **'Hearth & Habitat'**
  String get signInBrand;

  /// No description provided for @signInWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a casa'**
  String get signInWelcomeTitle;

  /// No description provided for @signInWelcomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ingresá con tu cuenta para coordinar tu hogar.'**
  String get signInWelcomeSubtitle;

  /// No description provided for @signInAccessCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Acceso al hogar'**
  String get signInAccessCardTitle;

  /// No description provided for @signInAccessCardDescription.
  ///
  /// In es, this message translates to:
  /// **'Sincronizá despensa, gastos y notas con quienes comparten el hogar.'**
  String get signInAccessCardDescription;

  /// No description provided for @signInContinueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get signInContinueWithGoogle;

  /// No description provided for @signInJoinExistingHomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Unite a un hogar existente'**
  String get signInJoinExistingHomeTitle;

  /// No description provided for @signInJoinExistingHomeDescription.
  ///
  /// In es, this message translates to:
  /// **'¿Tenés un código de invitación? Canjealo acá.'**
  String get signInJoinExistingHomeDescription;

  /// No description provided for @signInRedeemCode.
  ///
  /// In es, this message translates to:
  /// **'Canjear código'**
  String get signInRedeemCode;

  /// No description provided for @signInFooterTagline.
  ///
  /// In es, this message translates to:
  /// **'Vida sostenible · Diseño consciente'**
  String get signInFooterTagline;

  /// No description provided for @inviteDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Código de invitación'**
  String get inviteDialogTitle;

  /// No description provided for @inviteDialogHint.
  ///
  /// In es, this message translates to:
  /// **'Pegá el código o enlace'**
  String get inviteDialogHint;

  /// No description provided for @homeNoSession.
  ///
  /// In es, this message translates to:
  /// **'Sin sesión'**
  String get homeNoSession;

  /// No description provided for @homeProfileTooltip.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get homeProfileTooltip;

  /// No description provided for @homeSignOut.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get homeSignOut;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In es, this message translates to:
  /// **'Buenos días'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In es, this message translates to:
  /// **'Buenas tardes'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In es, this message translates to:
  /// **'Buenas noches'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingLine.
  ///
  /// In es, this message translates to:
  /// **'{greeting}, {firstName}'**
  String homeGreetingLine(String greeting, String firstName);

  /// No description provided for @homeHeroSubtitleWithFamily.
  ///
  /// In es, this message translates to:
  /// **'Acá tenés un vistazo del hogar: despensa, gastos, notas y recetas en un solo lugar.'**
  String get homeHeroSubtitleWithFamily;

  /// No description provided for @homeHeroSubtitleWithoutFamily.
  ///
  /// In es, this message translates to:
  /// **'Creá tu hogar para empezar a coordinar despensa, gastos y notas con quienes viven con vos.'**
  String get homeHeroSubtitleWithoutFamily;

  /// No description provided for @homeFamilyFallbackName.
  ///
  /// In es, this message translates to:
  /// **'familia'**
  String get homeFamilyFallbackName;

  /// No description provided for @homeLoadingSandboxPlans.
  ///
  /// In es, this message translates to:
  /// **'Cargando planes sandbox...'**
  String get homeLoadingSandboxPlans;

  /// No description provided for @homeFamilySpaceTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu espacio familiar'**
  String get homeFamilySpaceTitle;

  /// No description provided for @homeFamilySpaceDescription.
  ///
  /// In es, this message translates to:
  /// **'Creá un hogar para compartir despensa, gastos y notas.'**
  String get homeFamilySpaceDescription;

  /// No description provided for @homeCreateFamily.
  ///
  /// In es, this message translates to:
  /// **'Crear hogar'**
  String get homeCreateFamily;

  /// No description provided for @homeInvitations.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get homeInvitations;

  /// No description provided for @homeGenerateInvite.
  ///
  /// In es, this message translates to:
  /// **'Generar invitación'**
  String get homeGenerateInvite;

  /// No description provided for @inviteCreatedSheetTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitación lista'**
  String get inviteCreatedSheetTitle;

  /// No description provided for @inviteCreatedSheetSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Compartí este enlace con quien querés sumar al hogar. También podés copiarlo o usar el menú de compartir del sistema.'**
  String get inviteCreatedSheetSubtitle;

  /// No description provided for @inviteCreatedExpires.
  ///
  /// In es, this message translates to:
  /// **'Vence el {date}'**
  String inviteCreatedExpires(String date);

  /// No description provided for @inviteLinkCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace'**
  String get inviteLinkCopy;

  /// No description provided for @inviteLinkShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get inviteLinkShare;

  /// No description provided for @inviteCopiedToClipboard.
  ///
  /// In es, this message translates to:
  /// **'Enlace copiado'**
  String get inviteCopiedToClipboard;

  /// No description provided for @inviteCreateErrorPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'No podés crear invitaciones: revisá que tu suscripción incluya invitaciones a hogares.'**
  String get inviteCreateErrorPermissionDenied;

  /// No description provided for @inviteCreateErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la invitación: {message}'**
  String inviteCreateErrorGeneric(String message);

  /// No description provided for @invitesListTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get invitesListTitle;

  /// No description provided for @invitesEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay invitaciones pendientes'**
  String get invitesEmptyTitle;

  /// No description provided for @invitesEmptyDescription.
  ///
  /// In es, this message translates to:
  /// **'Generá un enlace para invitar a alguien a unirse a este hogar.'**
  String get invitesEmptyDescription;

  /// No description provided for @invitesPendingIntro.
  ///
  /// In es, this message translates to:
  /// **'Invitaciones pendientes para sumar miembros al hogar.'**
  String get invitesPendingIntro;

  /// No description provided for @invitesExpiresLabel.
  ///
  /// In es, this message translates to:
  /// **'Vence: {date}'**
  String invitesExpiresLabel(String date);

  /// No description provided for @invitesNoSession.
  ///
  /// In es, this message translates to:
  /// **'Sin sesión'**
  String get invitesNoSession;

  /// No description provided for @invitesNeedFamily.
  ///
  /// In es, this message translates to:
  /// **'Primero creá o unite a un hogar.'**
  String get invitesNeedFamily;

  /// No description provided for @homeActiveHousehold.
  ///
  /// In es, this message translates to:
  /// **'Hogar activo'**
  String get homeActiveHousehold;

  /// No description provided for @homeMonthlyRecognizedExpense.
  ///
  /// In es, this message translates to:
  /// **'Gasto reconocido del mes'**
  String get homeMonthlyRecognizedExpense;

  /// No description provided for @homeNoMonthlyMovements.
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos del mes'**
  String get homeNoMonthlyMovements;

  /// No description provided for @homeScan.
  ///
  /// In es, this message translates to:
  /// **'Escanear'**
  String get homeScan;

  /// No description provided for @homeCategoriesWithMovement.
  ///
  /// In es, this message translates to:
  /// **'Categorías con movimiento'**
  String get homeCategoriesWithMovement;

  /// No description provided for @homeStockAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas de despensa'**
  String get homeStockAlerts;

  /// No description provided for @homeNoStockAlerts.
  ///
  /// In es, this message translates to:
  /// **'No hay ítems marcados como \"no hay\" o \"queda poco\".'**
  String get homeNoStockAlerts;

  /// No description provided for @homeStockAlertsToReview.
  ///
  /// In es, this message translates to:
  /// **'{count} ítem{suffix} para revisar.'**
  String homeStockAlertsToReview(int count, String suffix);

  /// No description provided for @homeAllGoodForNow.
  ///
  /// In es, this message translates to:
  /// **'Todo en orden por ahora.'**
  String get homeAllGoodForNow;

  /// No description provided for @homeUnnamedItem.
  ///
  /// In es, this message translates to:
  /// **'(sin nombre)'**
  String get homeUnnamedItem;

  /// No description provided for @homeViewFullPantry.
  ///
  /// In es, this message translates to:
  /// **'Ver despensa completa'**
  String get homeViewFullPantry;

  /// No description provided for @homeRecentNote.
  ///
  /// In es, this message translates to:
  /// **'Nota reciente'**
  String get homeRecentNote;

  /// No description provided for @homeNoSharedNotesYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay notas compartidas.'**
  String get homeNoSharedNotesYet;

  /// No description provided for @homeUntitledNote.
  ///
  /// In es, this message translates to:
  /// **'(sin título)'**
  String get homeUntitledNote;

  /// No description provided for @homeFeaturedRecipe.
  ///
  /// In es, this message translates to:
  /// **'Receta destacada'**
  String get homeFeaturedRecipe;

  /// No description provided for @homeMinutes.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String homeMinutes(int minutes);

  /// No description provided for @homeServings.
  ///
  /// In es, this message translates to:
  /// **'{servings} porciones'**
  String homeServings(int servings);

  /// No description provided for @revenueCatTitle.
  ///
  /// In es, this message translates to:
  /// **'RevenueCat UI'**
  String get revenueCatTitle;

  /// No description provided for @revenueCatDescription.
  ///
  /// In es, this message translates to:
  /// **'Paywall y centro de cliente configurados en RevenueCat.'**
  String get revenueCatDescription;

  /// No description provided for @revenueCatPaywall.
  ///
  /// In es, this message translates to:
  /// **'Paywall'**
  String get revenueCatPaywall;

  /// No description provided for @revenueCatOpenPaywallPayment.
  ///
  /// In es, this message translates to:
  /// **'Pagar suscripción (sandbox)'**
  String get revenueCatOpenPaywallPayment;

  /// No description provided for @revenueCatCustomerCenter.
  ///
  /// In es, this message translates to:
  /// **'Centro de cliente'**
  String get revenueCatCustomerCenter;

  /// No description provided for @revenueCatPaywallError.
  ///
  /// In es, this message translates to:
  /// **'Paywall: {error}'**
  String revenueCatPaywallError(String error);

  /// No description provided for @revenueCatCustomerCenterError.
  ///
  /// In es, this message translates to:
  /// **'Centro de cliente: {error}'**
  String revenueCatCustomerCenterError(String error);

  /// No description provided for @billingAvailableTitle.
  ///
  /// In es, this message translates to:
  /// **'Planes premium disponibles'**
  String get billingAvailableTitle;

  /// No description provided for @billingAvailableMessage.
  ///
  /// In es, this message translates to:
  /// **'Encontramos {packageCount} paquete(s) en sandbox. Ya podés validar compras en entorno de pruebas.'**
  String billingAvailableMessage(int packageCount);

  /// No description provided for @billingNotConfiguredTitle.
  ///
  /// In es, this message translates to:
  /// **'Beneficios premium no disponibles en este entorno'**
  String get billingNotConfiguredTitle;

  /// No description provided for @billingNotConfiguredMessage.
  ///
  /// In es, this message translates to:
  /// **'Estamos terminando la configuración de suscripciones. Podés seguir usando todas las funciones base del hogar.'**
  String get billingNotConfiguredMessage;

  /// No description provided for @billingEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'No encontramos planes disponibles por ahora'**
  String get billingEmptyTitle;

  /// No description provided for @billingEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'No hay ofertas activas en este momento. Tu experiencia actual no cambia y podés intentar nuevamente en unos minutos.'**
  String get billingEmptyMessage;

  /// No description provided for @billingErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar los planes'**
  String get billingErrorTitle;

  /// No description provided for @billingErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'Revisá tu conexión e intentá de nuevo. Mientras tanto, podés seguir gestionando tu hogar con normalidad.'**
  String get billingErrorMessage;

  /// No description provided for @billingRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get billingRetry;

  /// No description provided for @billingRefreshPlans.
  ///
  /// In es, this message translates to:
  /// **'Actualizar planes'**
  String get billingRefreshPlans;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'AR':
            return AppLocalizationsEsAr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
