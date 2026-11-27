import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/alert_rule.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'alert_edit_screen.dart';
import 'web_view_screen.dart';

/// 알림 탭: smart keyword rules and the history of alerts the server sent.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알림'),
          bottom: const TabBar(
            indicatorColor: AppColors.main,
            labelColor: AppColors.main,
            unselectedLabelColor: AppColors.sub,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: '알림 조건'), Tab(text: '받은 알림')],
          ),
        ),
        body: const TabBarView(children: [_RulesTab(), _HistoryTab()]),
      ),
    );
  }
}

class _RulesTab extends StatefulWidget {
  const _RulesTab();

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  final repo = AppServices.instance.user;
  late final Stream<List<AlertRule>> _rules = repo.watchAlerts();

  void _edit(BuildContext context, [AlertRule? rule]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => AlertEditScreen(rule: rule)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-alert',
        backgroundColor: AppColors.main,
        foregroundColor: Colors.white,
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('조건 추가'),
      ),
      body: StreamBuilder<List<AlertRule>>(
        stream: _rules,
        builder: (context, snap) {
          if (snap.hasError) {
            return const _Empty(icon: Icons.cloud_off, text: '알림 조건을 불러오지 못했어요.');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          final rules = snap.data!;
          if (rules.isEmpty) {
            return const _Empty(
              icon: Icons.notifications_none,
              text: '원하는 상품을 등록하면\n핫딜이 올라오는 즉시 알려드려요.\n\n예: 에어팟 프로 · 25만원 이하 · 리퍼 제외',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rules[i];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  onTap: () => _edit(context, r),
                  title: Text(r.keyword, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.conditionSummary, style: const TextStyle(color: AppColors.sub, fontSize: 12.5)),
                  ),
                  trailing: Switch(
                    value: r.enabled,
                    onChanged: (v) => repo.saveAlert(r.copyWith(enabled: v)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final repo = AppServices.instance.user;
  late final Stream<List<SentAlert>> _sent = repo.watchSent();

  @override
  Widget build(BuildContext context) {
    if (!repo.supportsPush) {
      return const _Empty(icon: Icons.history, text: '서버에 연결되면 받은 알림이 여기에 쌓여요.');
    }
    return StreamBuilder<List<SentAlert>>(
      stream: _sent,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        final items = snap.data!;
        if (items.isEmpty) return const _Empty(icon: Icons.history, text: '아직 받은 알림이 없어요.');
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
          itemBuilder: (context, i) {
            final a = items[i];
            return ListTile(
              tileColor: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WebViewScreen(url: a.url, title: a.sourceName)),
              ),
              title: Text(a.productName, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  "'${a.keyword}'",
                  if (a.priceLabel != null) a.priceLabel!,
                  if (a.shop != null) a.shop!,
                  timeAgo(a.sentAt),
                  if (!a.delivered) '방해금지 중 보관',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.sub),
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.sub),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub, height: 1.6)),
            ],
          ),
        ),
      );
}
