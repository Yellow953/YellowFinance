import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/forgot_password_view.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/auth/views/splash_view.dart';
import '../modules/auth/views/verify_email_view.dart';
import '../modules/budgets/bindings/budget_binding.dart';
import '../modules/budgets/views/budgets_view.dart';
import '../modules/diary/bindings/diary_binding.dart';
import '../modules/diary/views/diary_entry_view.dart';
import '../modules/diary/views/diary_view.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/portfolio/bindings/portfolio_binding.dart';
import '../modules/portfolio/views/asset_detail_view.dart';
import '../modules/portfolio/views/portfolio_view.dart';
import '../modules/reports/bindings/reports_binding.dart';
import '../modules/reports/views/reports_view.dart';
import '../modules/sports/bindings/sport_binding.dart';
import '../modules/sports/views/sports_view.dart';
import '../modules/todos/bindings/todo_binding.dart';
import '../modules/todos/views/todos_view.dart';
import '../modules/transactions/bindings/transaction_binding.dart';
import '../modules/transactions/views/add_transaction_view.dart';
import '../modules/transactions/views/transactions_view.dart';
import 'app_routes.dart';

/// All named routes for GetX navigation.
abstract class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.SPLASH,
      page: () => const SplashView(),
    ),
    GetPage(
      name: AppRoutes.LOGIN,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.REGISTER,
      page: () => const RegisterView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.FORGOT_PASSWORD,
      page: () => const ForgotPasswordView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.VERIFY_EMAIL,
      page: () => const VerifyEmailView(),
    ),
    GetPage(
      name: AppRoutes.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.TODOS,
      page: () => const TodosView(),
      binding: TodoBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.SPORTS,
      page: () => const SportsView(),
      binding: SportBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.TRANSACTIONS,
      page: () => const TransactionsView(),
      binding: TransactionBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.ADD_TRANSACTION,
      page: () => const AddTransactionView(),
      binding: TransactionBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.PORTFOLIO,
      page: () => const PortfolioView(),
      binding: PortfolioBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.REPORTS,
      page: () => const ReportsView(),
      binding: ReportsBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.DIARY,
      page: () => const DiaryView(),
      binding: DiaryBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.DIARY_ENTRY,
      page: () => const DiaryEntryView(),
      binding: DiaryBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.BUDGETS,
      page: () => const BudgetsView(),
      binding: BudgetBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.PROFILE,
      page: () => const ProfileView(),
      middlewares: [AuthMiddleware()],
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.ASSET_DETAIL,
      page: () => const AssetDetailView(),
      middlewares: [AuthMiddleware()],
      transition: Transition.cupertino,
    ),
  ];
}

/// Blocks protected routes for anyone not signed in and verified.
///
/// [AuthController]'s `authStateChanges` listener redirects too, but reactively:
/// it fires *after* a route has been built, which is a frame too late for a
/// screen that reads user data on the way up. This runs before the page or its
/// binding is constructed, so an unauthenticated navigation never reaches a
/// controller at all.
///
/// The check reads Firebase directly rather than `AuthController.user`, which
/// is populated asynchronously from a Firestore profile fetch. On cold start
/// `main()` routes straight to Home from Firebase's cached session while that
/// fetch is still in flight — guarding on the profile would bounce a legitimate
/// session to the login screen every launch.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const RouteSettings(name: AppRoutes.LOGIN);
    }
    // Google accounts arrive verified; only email/password sign-ups are gated.
    final isVerified = user.emailVerified ||
        user.providerData.any((p) => p.providerId == 'google.com');
    if (!isVerified) {
      return const RouteSettings(name: AppRoutes.VERIFY_EMAIL);
    }
    return null;
  }
}
