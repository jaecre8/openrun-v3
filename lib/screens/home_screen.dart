import 'package:flutter/material.dart';
import '../models/post_item.dart';
import '../services/ppomppu_service.dart';
import '../services/fmkorea_service.dart';
import '../services/rss_service.dart';
import '../services/clien_service.dart';
import '../widgets/post_card.dart';
import 'keyword_screen.dart';

class OpenRunHomeScreen extends StatelessWidget {
  const OpenRunHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFFF90069);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        // 고정된 앱바 구조 (새로고침 간섭 제거)
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Image.asset(
            'assets/images/splash/openrun_logo.png',
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'OPENRUN',
              style: TextStyle(color: mainColor, fontWeight: FontWeight.w900),
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined, color: Colors.black54),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KeywordScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            indicatorColor: mainColor,
            labelColor: mainColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "뽐뿌게시판"),
              Tab(text: "해외뽐뿌"),
              Tab(text: "루리웹 핫딜"),
              Tab(text: "펨코 핫딜"),
              Tab(text: "클리앙 알뜰구매"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BoardListView(boardType: 'ppomppu'),
            BoardListView(boardType: 'ppomppu4'),
            BoardListView(boardType: 'ruliweb'),
            BoardListView(boardType: 'fmkorea'),
            BoardListView(boardType: 'clien'),
          ],
        ),
      ),
    );
  }
}

class BoardListView extends StatefulWidget {
  final String boardType;
  const BoardListView({super.key, required this.boardType});

  @override
  State<BoardListView> createState() => _BoardListViewState();
}

class _BoardListViewState extends State<BoardListView> {
  final List<PostItem> _items = [];
  int _page = 1;
  int _clienPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      List<PostItem> newItems = [];
      switch (widget.boardType) {
        case 'clien':
          newItems = await ClienService.fetchClien(page: _clienPage);
          _clienPage++;
          break;
        case 'ruliweb':
          newItems = await RssService.fetchRuliweb();
          _hasMore = false;
          break;
        case 'fmkorea':
          newItems = await FmKoreaService.fetchFmKorea(page: _page);
          _page++;
          break;
        default:
          newItems = await PpomppuService.fetchBoard(boardId: widget.boardType, page: _page);
          _page++;
      }

      if (mounted) {
        setState(() {
          if (newItems.isEmpty && _items.isEmpty) {
            _errorMsg = "게시글이 없습니다.";
          } else {
            _items.addAll(newItems);
          }
          _isLoading = false;
          if (newItems.isEmpty) _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = "데이터를 가져오지 못했습니다.";
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _clienPage = 0;
      _hasMore = true;
      _errorMsg = null;
    });
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            Text(_errorMsg!, textAlign: TextAlign.center),
            TextButton(onPressed: _fetchData, child: const Text("다시 시도")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFFF90069),
      backgroundColor: Colors.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            // 페이징 처리 시 setState 에러 방지를 위해 microtask 사용
            if (!_isLoading && _hasMore) {
              Future.microtask(() => _fetchData());
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return PostCard(item: _items[index]);
        },
      ),
    );
  }
}