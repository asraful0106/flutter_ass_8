import 'package:ass_8/features/home/presentation/pages/home_page.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  static const String home = "/";

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(path: "/", builder: (context, state) =>  HomePage(),)
    ]
  );
}