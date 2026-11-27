import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/alert_rule.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = AppServices.instance.user;
  late final Stream<PushSettings> _settings = _repo.watchSettings();
  bool _testing = false;

  Future<int?> _pickHour(int initial) => showModalBottomSheet<int>(
        context: context,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (ctx) => SizedBox(
          height: 320,
          child: ListView(
            children: [
              for (var h = 0; h < 24; h++)
                ListTile(
                  title: Text(_hourLabel(h)),
                  trailing: h == initial ? const Icon(Icons.check, color: AppColors.main) : null,
                  onTap: () => Navigator.pop(ctx, h),
                ),
            ],
          ),
        ),
      );

  static String _hourLabel(int h) => h < 12 ? '오전 ${h == 0 ? 12 : h}시' : '오후 ${h == 12 ? 12 : h - 12}시';

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    String msg;
    try {
      final sent = await _repo.sendTestPush();
      msg = sent > 0 ? '테스트 알림을 보냈어요.' : '이 기기의 알림 권한을 확인해 주세요.';
    } catch (e) {
      msg = '테스트 알림을 보내지 못했어요.';
    }
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: StreamBuilder<PushSettings>(
        stream: _settings,
        builder: (context, snap) {
          final s = snap.data ?? const PushSettings();
          return ListView(
            children: [
              const _Section('알림'),
              SwitchListTile(
                tileColor: Colors.white,
                title: const Text('핫딜 푸시 알림'),
                subtitle: const Text('알림 조건에 맞는 딜이 올라오면 바로 알려드려요'),
                value: s.pushEnabled,
                onChanged: (v) => _repo.saveSettings(PushSettings(pushEnabled: v, quietStart: s.quietStart, quietEnd: s.quietEnd)),
              ),
              SwitchListTile(
                tileColor: Colors.white,
                title: const Text('방해금지 시간'),
                subtitle: Text(s.quietEnabled
                    ? '${_hourLabel(s.quietStart!)} ~ ${_hourLabel(s.quietEnd!)}에는 소리 없이 기록만 해요'
                    : '꺼짐'),
                value: s.quietEnabled,
                onChanged: (v) => _repo.saveSettings(
                    PushSettings(pushEnabled: s.pushEnabled, quietStart: v ? 23 : null, quietEnd: v ? 7 : null)),
              ),
              if (s.quietEnabled) ...[
                ListTile(
                  tileColor: Colors.white,
                  title: const Text('시작'),
                  trailing: Text(_hourLabel(s.quietStart!)),
                  onTap: () async {
                    final h = await _pickHour(s.quietStart!);
                    if (h != null) _repo.saveSettings(PushSettings(pushEnabled: s.pushEnabled, quietStart: h, quietEnd: s.quietEnd));
                  },
                ),
                ListTile(
                  tileColor: Colors.white,
                  title: const Text('종료'),
                  trailing: Text(_hourLabel(s.quietEnd!)),
                  onTap: () async {
                    final h = await _pickHour(s.quietEnd!);
                    if (h != null) _repo.saveSettings(PushSettings(pushEnabled: s.pushEnabled, quietStart: s.quietStart, quietEnd: h));
                  },
                ),
              ],
              if (_repo.supportsPush)
                ListTile(
                  tileColor: Colors.white,
                  title: const Text('테스트 알림 보내기'),
                  trailing: _testing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _testing ? null : _sendTest,
                ),
              const _Section('정보'),
              const ListTile(
                tileColor: Colors.white,
                title: Text('수집 커뮤니티'),
                subtitle: Text('뽐뿌 · 해외뽐뿌 · 루리웹 · 클리앙 · 아카라이브'),
              ),
              ListTile(
                tileColor: Colors.white,
                title: const Text('데이터'),
                trailing: Text(AppServices.instance.mode == DataMode.firebase ? '실시간 서버' : '샘플 데이터 (개발용)',
                    style: const TextStyle(color: AppColors.sub)),
              ),
              const ListTile(tileColor: Colors.white, title: Text('버전'), trailing: Text('3.0.0', style: TextStyle(color: AppColors.sub))),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub)),
      );
}
