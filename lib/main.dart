import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'app_services.dart';
import 'screens/main_shell.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.init();
  runApp(const OpenRunApp());
  // Not awaited: neither should delay the first frame.
  services.migrateLegacyKeywords();
  NotificationService.init();
}

class OpenRunApp extends StatelessWidget {
  const OpenRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '오픈런',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
      theme: buildTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      locale: const Locale('ko'),
      home: const Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1200), () => Get.offAll(() => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.main,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/common/ci_run_white.png',
                    width: 253,
                    height: 42,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.bolt, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 8),
                  const Text('커뮤니티 핫딜, 가장 빠르게',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          ),
          const Text('We are newTypes', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
