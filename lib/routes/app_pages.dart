import 'package:get/get.dart';
import '../modules/ai/bindings/ai_binding.dart';
import '../modules/ai/views/ai_chat_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/forgot_password_view.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/auth/views/verify_email_view.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/portfolio/bindings/portfolio_binding.dart';
import '../modules/portfolio/views/asset_detail_view.dart';
import '../modules/portfolio/views/portfolio_view.dart';
import '../modules/reports/bindings/reports_binding.dart';
import '../modules/reports/views/reports_view.dart';
import '../modules/transactions/bindings/transaction_binding.dart';
import '../modules/transactions/views/add_transaction_view.dart';
import '../modules/transactions/views/transactions_view.dart';
import 'app_routes.dart';

/// All named routes for GetX navigation.
abstract class AppPages {
  static final routes = [
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
      name: AppRoutes.AI_CHAT,
      page: () => const AiChatView(),
      binding: AiBinding(),
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

/// Placeholder middleware — full auth guard is handled by AuthController stream.
class AuthMiddleware extends GetMiddleware {}
