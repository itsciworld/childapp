import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vigil1/services/background_services/background_services.dart';

import 'core/config/env_config.dart';
import 'route_names.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before anything that reads them.
  await EnvConfig.load();

  await BackgroundService.initializeService();

  // ProviderScope makes Riverpod providers available to the whole app.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigil - Parental Control App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: RouteNames.home,
      routes: AppRoutes.routes,
    );
  }
}
