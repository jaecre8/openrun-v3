import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, this.title = '원글 보기'});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWebResourceError: (e) => debugPrint('Webview Error: ${e.description}'),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openExternal() async {
    final current = await _controller.currentUrl() ?? widget.url;
    await launchUrl(Uri.parse(current), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '브라우저로 열기',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openExternal,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 100
              ? LinearProgressIndicator(value: _progress / 100, minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
