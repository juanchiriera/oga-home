// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Oga - housekeeper';

  @override
  String get assistantTooltip => 'Asistente';

  @override
  String get navHome => 'Inicio';

  @override
  String get navStock => 'Stock';

  @override
  String get navExpenses => 'Gastos';

  @override
  String get navRecipes => 'Recetas';

  @override
  String get navNotes => 'Notas';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get signInBrand => 'Hearth & Habitat';

  @override
  String get signInWelcomeTitle => 'Bienvenido a casa';

  @override
  String get signInWelcomeSubtitle =>
      'Ingresá con tu cuenta para coordinar tu hogar.';

  @override
  String get signInAccessCardTitle => 'Acceso al hogar';

  @override
  String get signInAccessCardDescription =>
      'Sincronizá despensa, gastos y notas con quienes comparten el hogar.';

  @override
  String get signInContinueWithGoogle => 'Continuar con Google';

  @override
  String get signInJoinExistingHomeTitle => 'Unite a un hogar existente';

  @override
  String get signInJoinExistingHomeDescription =>
      '¿Tenés un código de invitación? Canjealo acá.';

  @override
  String get signInRedeemCode => 'Canjear código';

  @override
  String get signInFooterTagline => 'Vida sostenible · Diseño consciente';

  @override
  String get inviteDialogTitle => 'Código de invitación';

  @override
  String get inviteDialogHint => 'Pegá el código o enlace';

  @override
  String get homeNoSession => 'Sin sesión';

  @override
  String get homeProfileTooltip => 'Perfil';

  @override
  String get homeSignOut => 'Salir';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String homeGreetingLine(String greeting, String firstName) {
    return '$greeting, $firstName';
  }

  @override
  String get homeHeroSubtitleWithFamily =>
      'Acá tenés un vistazo del hogar: despensa, gastos, notas y recetas en un solo lugar.';

  @override
  String get homeHeroSubtitleWithoutFamily =>
      'Creá tu hogar para empezar a coordinar despensa, gastos y notas con quienes viven con vos.';

  @override
  String get homeFamilyFallbackName => 'familia';

  @override
  String get homeLoadingSandboxPlans => 'Cargando planes sandbox...';

  @override
  String get homeFamilySpaceTitle => 'Tu espacio familiar';

  @override
  String get homeFamilySpaceDescription =>
      'Creá un hogar para compartir despensa, gastos y notas.';

  @override
  String get homeCreateFamily => 'Crear hogar';

  @override
  String get homeInvitations => 'Invitaciones';

  @override
  String get homeGenerateInvite => 'Generar invitación';

  @override
  String get inviteCreatedSheetTitle => 'Invitación lista';

  @override
  String get inviteCreatedSheetSubtitle =>
      'Compartí este enlace con quien querés sumar al hogar. También podés copiarlo o usar el menú de compartir del sistema.';

  @override
  String inviteCreatedExpires(String date) {
    return 'Vence el $date';
  }

  @override
  String get inviteLinkCopy => 'Copiar enlace';

  @override
  String get inviteLinkShare => 'Compartir';

  @override
  String get inviteCopiedToClipboard => 'Enlace copiado';

  @override
  String get inviteCreateErrorPermissionDenied =>
      'No tenés permiso para crear invitaciones en este hogar (solo administradores) o falta habilitar invitaciones en la suscripción.';

  @override
  String inviteCreateErrorGeneric(String message) {
    return 'No se pudo crear la invitación: $message';
  }

  @override
  String get invitesListTitle => 'Invitaciones';

  @override
  String get invitesEmptyTitle => 'No hay invitaciones pendientes';

  @override
  String get invitesEmptyDescription =>
      'Generá un enlace para invitar a alguien a unirse a este hogar.';

  @override
  String get invitesPendingIntro =>
      'Invitaciones pendientes para sumar miembros al hogar.';

  @override
  String invitesExpiresLabel(String date) {
    return 'Vence: $date';
  }

  @override
  String get invitesNoSession => 'Sin sesión';

  @override
  String get invitesNeedFamily => 'Primero creá o unite a un hogar.';

  @override
  String get homeActiveHousehold => 'Hogar activo';

  @override
  String get homeMonthlyRecognizedExpense => 'Gasto reconocido del mes';

  @override
  String get homeNoMonthlyMovements => 'Sin movimientos del mes';

  @override
  String get homeScan => 'Escanear';

  @override
  String get homeCategoriesWithMovement => 'Categorías con movimiento';

  @override
  String get homeStockAlerts => 'Alertas de despensa';

  @override
  String get homeNoStockAlerts =>
      'No hay ítems marcados como \"no hay\" o \"queda poco\".';

  @override
  String homeStockAlertsToReview(int count, String suffix) {
    return '$count ítem$suffix para revisar.';
  }

  @override
  String get homeAllGoodForNow => 'Todo en orden por ahora.';

  @override
  String get homeUnnamedItem => '(sin nombre)';

  @override
  String get homeViewFullPantry => 'Ver despensa completa';

  @override
  String get homeRecentNote => 'Nota reciente';

  @override
  String get homeNoSharedNotesYet => 'Todavía no hay notas compartidas.';

  @override
  String get homeUntitledNote => '(sin título)';

  @override
  String get homeFeaturedRecipe => 'Receta destacada';

  @override
  String homeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String homeServings(int servings) {
    return '$servings porciones';
  }

  @override
  String get revenueCatTitle => 'RevenueCat UI';

  @override
  String get revenueCatDescription =>
      'Paywall y centro de cliente configurados en RevenueCat.';

  @override
  String get revenueCatPaywall => 'Paywall';

  @override
  String get revenueCatOpenPaywallPayment => 'Pagar suscripción (sandbox)';

  @override
  String get revenueCatCustomerCenter => 'Centro de cliente';

  @override
  String revenueCatPaywallError(String error) {
    return 'Paywall: $error';
  }

  @override
  String revenueCatCustomerCenterError(String error) {
    return 'Centro de cliente: $error';
  }

  @override
  String get billingAvailableTitle => 'Planes premium disponibles';

  @override
  String billingAvailableMessage(int packageCount) {
    return 'Encontramos $packageCount paquete(s) en sandbox. Ya podés validar compras en entorno de pruebas.';
  }

  @override
  String get billingNotConfiguredTitle =>
      'Beneficios premium no disponibles en este entorno';

  @override
  String get billingNotConfiguredMessage =>
      'Estamos terminando la configuración de suscripciones. Podés seguir usando todas las funciones base del hogar.';

  @override
  String get billingEmptyTitle => 'No encontramos planes disponibles por ahora';

  @override
  String get billingEmptyMessage =>
      'No hay ofertas activas en este momento. Tu experiencia actual no cambia y podés intentar nuevamente en unos minutos.';

  @override
  String get billingErrorTitle => 'No pudimos cargar los planes';

  @override
  String get billingErrorMessage =>
      'Revisá tu conexión e intentá de nuevo. Mientras tanto, podés seguir gestionando tu hogar con normalidad.';

  @override
  String get billingRetry => 'Reintentar';

  @override
  String get billingRefreshPlans => 'Actualizar planes';
}

/// The translations for Spanish Castilian, as used in Argentina (`es_AR`).
class AppLocalizationsEsAr extends AppLocalizationsEs {
  AppLocalizationsEsAr() : super('es_AR');

  @override
  String get appTitle => 'Oga - housekeeper';

  @override
  String get assistantTooltip => 'Asistente';

  @override
  String get navHome => 'Inicio';

  @override
  String get navStock => 'Stock';

  @override
  String get navExpenses => 'Gastos';

  @override
  String get navRecipes => 'Recetas';

  @override
  String get navNotes => 'Notas';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get signInBrand => 'Hearth & Habitat';

  @override
  String get signInWelcomeTitle => 'Bienvenido a casa';

  @override
  String get signInWelcomeSubtitle =>
      'Ingresá con tu cuenta para coordinar tu hogar.';

  @override
  String get signInAccessCardTitle => 'Acceso al hogar';

  @override
  String get signInAccessCardDescription =>
      'Sincronizá despensa, gastos y notas con quienes comparten el hogar.';

  @override
  String get signInContinueWithGoogle => 'Continuar con Google';

  @override
  String get signInJoinExistingHomeTitle => 'Unite a un hogar existente';

  @override
  String get signInJoinExistingHomeDescription =>
      '¿Tenés un código de invitación? Canjealo acá.';

  @override
  String get signInRedeemCode => 'Canjear código';

  @override
  String get signInFooterTagline => 'Vida sostenible · Diseño consciente';

  @override
  String get inviteDialogTitle => 'Código de invitación';

  @override
  String get inviteDialogHint => 'Pegá el código o enlace';

  @override
  String get homeNoSession => 'Sin sesión';

  @override
  String get homeProfileTooltip => 'Perfil';

  @override
  String get homeSignOut => 'Salir';

  @override
  String get homeGreetingMorning => 'Buenos días';

  @override
  String get homeGreetingAfternoon => 'Buenas tardes';

  @override
  String get homeGreetingEvening => 'Buenas noches';

  @override
  String homeGreetingLine(String greeting, String firstName) {
    return '$greeting, $firstName';
  }

  @override
  String get homeHeroSubtitleWithFamily =>
      'Acá tenés un vistazo del hogar: despensa, gastos, notas y recetas en un solo lugar.';

  @override
  String get homeHeroSubtitleWithoutFamily =>
      'Creá tu hogar para empezar a coordinar despensa, gastos y notas con quienes viven con vos.';

  @override
  String get homeFamilyFallbackName => 'familia';

  @override
  String get homeLoadingSandboxPlans => 'Cargando planes sandbox...';

  @override
  String get homeFamilySpaceTitle => 'Tu espacio familiar';

  @override
  String get homeFamilySpaceDescription =>
      'Creá un hogar para compartir despensa, gastos y notas.';

  @override
  String get homeCreateFamily => 'Crear hogar';

  @override
  String get homeInvitations => 'Invitaciones';

  @override
  String get homeGenerateInvite => 'Generar invitación';

  @override
  String get inviteCreatedSheetTitle => 'Invitación lista';

  @override
  String get inviteCreatedSheetSubtitle =>
      'Compartí este enlace con quien querés sumar al hogar. También podés copiarlo o usar el menú de compartir del sistema.';

  @override
  String inviteCreatedExpires(String date) {
    return 'Vence el $date';
  }

  @override
  String get inviteLinkCopy => 'Copiar enlace';

  @override
  String get inviteLinkShare => 'Compartir';

  @override
  String get inviteCopiedToClipboard => 'Enlace copiado';

  @override
  String get inviteCreateErrorPermissionDenied =>
      'No tenés permiso para crear invitaciones en este hogar (solo administradores) o falta habilitar invitaciones en la suscripción.';

  @override
  String inviteCreateErrorGeneric(String message) {
    return 'No se pudo crear la invitación: $message';
  }

  @override
  String get invitesListTitle => 'Invitaciones';

  @override
  String get invitesEmptyTitle => 'No hay invitaciones pendientes';

  @override
  String get invitesEmptyDescription =>
      'Generá un enlace para invitar a alguien a unirse a este hogar.';

  @override
  String get invitesPendingIntro =>
      'Invitaciones pendientes para sumar miembros al hogar.';

  @override
  String invitesExpiresLabel(String date) {
    return 'Vence: $date';
  }

  @override
  String get invitesNoSession => 'Sin sesión';

  @override
  String get invitesNeedFamily => 'Primero creá o unite a un hogar.';

  @override
  String get homeActiveHousehold => 'Hogar activo';

  @override
  String get homeMonthlyRecognizedExpense => 'Gasto reconocido del mes';

  @override
  String get homeNoMonthlyMovements => 'Sin movimientos del mes';

  @override
  String get homeScan => 'Escanear';

  @override
  String get homeCategoriesWithMovement => 'Categorías con movimiento';

  @override
  String get homeStockAlerts => 'Alertas de despensa';

  @override
  String get homeNoStockAlerts =>
      'No hay ítems marcados como \"no hay\" o \"queda poco\".';

  @override
  String homeStockAlertsToReview(int count, String suffix) {
    return '$count ítem$suffix para revisar.';
  }

  @override
  String get homeAllGoodForNow => 'Todo en orden por ahora.';

  @override
  String get homeUnnamedItem => '(sin nombre)';

  @override
  String get homeViewFullPantry => 'Ver despensa completa';

  @override
  String get homeRecentNote => 'Nota reciente';

  @override
  String get homeNoSharedNotesYet => 'Todavía no hay notas compartidas.';

  @override
  String get homeUntitledNote => '(sin título)';

  @override
  String get homeFeaturedRecipe => 'Receta destacada';

  @override
  String homeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String homeServings(int servings) {
    return '$servings porciones';
  }

  @override
  String get revenueCatTitle => 'RevenueCat UI';

  @override
  String get revenueCatDescription =>
      'Paywall y centro de cliente configurados en RevenueCat.';

  @override
  String get revenueCatPaywall => 'Paywall';

  @override
  String get revenueCatOpenPaywallPayment => 'Pagar suscripción (sandbox)';

  @override
  String get revenueCatCustomerCenter => 'Centro de cliente';

  @override
  String revenueCatPaywallError(String error) {
    return 'Paywall: $error';
  }

  @override
  String revenueCatCustomerCenterError(String error) {
    return 'Centro de cliente: $error';
  }

  @override
  String get billingAvailableTitle => 'Planes premium disponibles';

  @override
  String billingAvailableMessage(int packageCount) {
    return 'Encontramos $packageCount paquete(s) en sandbox. Ya podés validar compras en entorno de pruebas.';
  }

  @override
  String get billingNotConfiguredTitle =>
      'Beneficios premium no disponibles en este entorno';

  @override
  String get billingNotConfiguredMessage =>
      'Estamos terminando la configuración de suscripciones. Podés seguir usando todas las funciones base del hogar.';

  @override
  String get billingEmptyTitle => 'No encontramos planes disponibles por ahora';

  @override
  String get billingEmptyMessage =>
      'No hay ofertas activas en este momento. Tu experiencia actual no cambia y podés intentar nuevamente en unos minutos.';

  @override
  String get billingErrorTitle => 'No pudimos cargar los planes';

  @override
  String get billingErrorMessage =>
      'Revisá tu conexión e intentá de nuevo. Mientras tanto, podés seguir gestionando tu hogar con normalidad.';

  @override
  String get billingRetry => 'Reintentar';

  @override
  String get billingRefreshPlans => 'Actualizar planes';
}
