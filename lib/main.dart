import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 서비스 및 화면 임포트 (프로젝트 구조에 맞게 확인)
import 'screens/home_screen.dart';
import 'screens/keyword_screen.dart';
import 'services/notification_service.dart';
import 'services/ppomppu_service.dart';
import 'services/fmkorea_service.dart';
import 'services/clien_service.dart';
import 'services/rss_service.dart';
import 'models/post_item.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    // [수정] 키워드 리스트가 비어있으면 기본값으로 ["무료"]를 사용합니다.
    final List<String> keywords = prefs.getStringList('my_keywords') ?? ["무료"];
    final String lastLink = prefs.getString('last_notified_link') ?? '';

    try {
      final Map<String, List<PostItem>> boardData = {
        "뽐뿌게시판": await PpomppuService.fetchBoard(boardId: 'ppomppu'),
        "해외뽐뿌": await PpomppuService.fetchBoard(boardId: 'ppomppu4'),
        "루리웹 핫딜": await RssService.fetchRuliweb(),
        "펨코 핫딜": await FmKoreaService.fetchFmKorea(page: 1),
        "클리앙 알뜰구매": await ClienService.fetchClien(page: 0),
      };

      for (var entry in boardData.entries) {
        String boardName = entry.key;
        List<PostItem> posts = entry.value;

        for (var post in posts) {
          if (post.link == lastLink) break;
          for (var keyword in keywords) {
            if (post.title.contains(keyword)) {
              await NotificationService.showNotification(
                title: "🔥 [$boardName] $keyword 포착!",
                body: post.title,
              );
              await prefs.setString('last_notified_link', post.link);
              return Future.value(true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Background Error: $e");
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    "openrun_periodic_check",
    "fetchLatestDeals",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );

  runApp(const OpenRunApp());
}

class OpenRunApp extends StatelessWidget {
  const OpenRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFF90069),
        fontFamily: 'Noto_SansCJK_KR',
        brightness: Brightness.light,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', ''), Locale('en', '')],
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
    Timer(const Duration(milliseconds: 1500), () => Get.offAll(() => const OpenRunHomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF90069),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/common/ci_run_white.png',
                    width: 253, height: 42, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.bolt, color: Colors.white, size: 50),
                  ),
                  const SizedBox(height: 5),
                  const Text("실시간 쇼핑 대란 알림", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          ),
          const Text("We are newTypes", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}