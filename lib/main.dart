import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/notification_service.dart';
import 'package:smart_campus/core/theme.dart';
import 'package:smart_campus/data/local/app_database.dart';
import 'package:smart_campus/data/repositories/sqlite_campus_repository.dart';
import 'package:smart_campus/domain/campus_repository.dart';
import 'package:smart_campus/features/auth/auth_provider.dart';
import 'package:smart_campus/features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Opens the database; on first launch this creates the tables and demo data.
  await AppDatabase.instance.database;
  await NotificationService.instance.init();
  // To use a real backend later, replace this with your own CampusRepository.
  final CampusRepository repo = SqliteCampusRepository();
  runApp(
    MultiProvider(
      providers: [
        Provider<CampusRepository>.value(value: repo),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(repo)),
        ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(repo)..load()),
      ],
      child: const SmartCampusApp(),
    ),
  );
}

class SmartCampusApp extends StatelessWidget {
  const SmartCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const SplashScreen(),
    );
  }
}
