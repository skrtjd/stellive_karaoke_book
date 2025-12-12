import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_data_manager.dart';

/// --------------------------------------------------
/// 앱 테마 설정 (시스템 / 라이트 / 다크)
/// --------------------------------------------------
enum AppTheme {
  system, // 폰 설정 따라가기
  light,  // 항상 화이트
  dark,   // 항상 다크
}

/// --------------------------------------------------
/// 공지 팝업 설정 (ON/OFF)
/// --------------------------------------------------
class NoticePrefs {
  static const _key = 'noticePushEnabled';

  /// 저장된 값 로드 (기본값: true = 공지 팝업 켜짐)
  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  /// 값 저장
  static Future<void> save(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

/// --------------------------------------------------
/// 앱 테마 SharedPreferences 저장/로드
/// --------------------------------------------------
class ThemePrefs {
  static const _key = 'appThemeMode';

  static Future<AppTheme> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key) ?? 'system';
    switch (value) {
      case 'light':
        return AppTheme.light;
      case 'dark':
        return AppTheme.dark;
      default:
        return AppTheme.system;
    }
  }

  static Future<void> save(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    late String v;
    switch (theme) {
      case AppTheme.light:
        v = 'light';
        break;
      case AppTheme.dark:
        v = 'dark';
        break;
      case AppTheme.system:
        v = 'system';
        break;
    }
    await prefs.setString(_key, v);
  }
}

/// --------------------------------------------------
/// main
/// --------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteDataManager.init();
  runApp(const MyApp());
}

/// --------------------------------------------------
/// MyApp: 앱 전체 테마 관리 + MainScreen으로 전달
/// --------------------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppTheme _appTheme = AppTheme.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final t = await ThemePrefs.load();
    setState(() {
      _appTheme = t;
    });
  }

  ThemeMode _toThemeMode(AppTheme t) {
    switch (t) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  void _changeTheme(AppTheme t) {
    setState(() {
      _appTheme = t;
    });
    ThemePrefs.save(t);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stella Karaoke',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _toThemeMode(_appTheme),
      home: MainScreen(
        currentTheme: _appTheme,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

/// --------------------------------------------------
/// 공통: AppBar 오른쪽 액션 (멤버 목록 / 검색 / 즐겨찾기 버튼)
/// (설정 버튼은 MainScreen에서 따로 추가)
/// --------------------------------------------------
List<Widget> buildAppBarActions(
    BuildContext context,
    Set<String> favorites,
    void Function(String) toggleFav,
    ) {
  return [
    // 🔹 멤버 목록 바로가기 버튼
    IconButton(
      icon: const Icon(Icons.group),
      tooltip: '멤버 목록',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(
                title: const Text('멤버'),
                actions: buildAppBarActions(ctx, favorites, toggleFav),
              ),
              body: MemberListBody(
                favorites: favorites,
                toggleFav: toggleFav,
              ),
            ),
          ),
        );
      },
    ),

    // 🔍 검색
    IconButton(
      icon: const Icon(Icons.search),
      tooltip: '검색',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(
                title: const Text('검색'),
                actions: buildAppBarActions(ctx, favorites, toggleFav),
              ),
              body: SearchPage(
                favorites: favorites,
                toggleFav: toggleFav,
              ),
            ),
          ),
        );
      },
    ),

    // ⭐ 즐겨찾기
    IconButton(
      icon: const Icon(Icons.star),
      tooltip: '즐겨찾기',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              appBar: AppBar(
                title: const Text('즐겨찾기'),
                actions: buildAppBarActions(ctx, favorites, toggleFav),
              ),
              body: FavoritePage(
                favorites: favorites,
                toggleFav: toggleFav,
              ),
            ),
          ),
        );
      },
    ),
  ];
}

/// --------------------------------------------------
/// 즐겨찾기 저장/로드 + 순서 관리
/// --------------------------------------------------
class FavoriteManager {
  static const String keySet = "favoriteSongs"; // 즐겨찾기 집합
  static const String keyOrder = "favoriteOrder"; // 즐겨찾기 순서

  /// Set 로드
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keySet);
    return list?.toSet() ?? <String>{};
  }

  /// Set 저장 (즐겨찾기 on/off 할 때 사용)
  static Future<void> save(Set<String> titles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keySet, titles.toList());

    // 순서 리스트에서 없는 곡은 자동 정리
    final currentOrder = prefs.getStringList(keyOrder) ?? <String>[];
    final cleaned = currentOrder.where((t) => titles.contains(t)).toList();
    await prefs.setStringList(keyOrder, cleaned);
  }

  /// 현재 favorites(Set) 를 기준으로, 순서 리스트 로드
  static Future<List<String>> loadOrder(Set<String> currentSet) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(keyOrder) ?? <String>[];

    // 1) Set에 존재하는 것만 남기기
    final ordered = saved.where((t) => currentSet.contains(t)).toList();

    // 2) Set에는 있는데 saved에 없는 곡은 뒤에 추가
    for (final t in currentSet) {
      if (!ordered.contains(t)) {
        ordered.add(t);
      }
    }

    return ordered;
  }

  /// 순서 저장 (드래그 후 호출)
  static Future<void> saveOrder(List<String> orderedTitles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyOrder, orderedTitles);
  }
}

/// --------------------------------------------------
/// 공지 모델 + 오늘 하루 보지 않기 관리
/// --------------------------------------------------
class Notice {
  final String id; // "01", "02" ...
  final String type; // "update", "bugfix", "event", ...
  final String title;
  final String body;
  final DateTime? date; // 공지 날짜 (YYYY-MM-DD)

  Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.date,
  });

  factory Notice.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? '').toString();
    final type = (j['type'] ?? '').toString();
    final title = (j['title'] ?? '').toString();
    final body = (j['body'] ?? '').toString();

    DateTime? parsedDate;
    final dateStr = (j['date'] ?? '').toString().trim();
    if (dateStr.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        parsedDate = null;
      }
    }

    return Notice(
      id: id,
      type: type,
      title: title,
      body: body,
      date: parsedDate,
    );
  }
}

class NoticeManager {
  static const _hiddenPrefix = 'noticeHidden_';

  static Future<List<Notice>> loadNotices() async {
    final txt = await safeLoadJsonString('notices.json');
    final raw = jsonDecode(txt);
    if (raw is! List) return <Notice>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((j) => Notice.fromJson(j))
        .toList();
  }

  static Future<bool> isHiddenToday(Notice n) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenKey(n);
    final todayStr = _dateString(DateTime.now());
    final saved = prefs.getString(key);
    return saved == todayStr;
  }

  static Future<void> hideToday(Notice n) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _hiddenKey(n);
    final todayStr = _dateString(DateTime.now());
    await prefs.setString(key, todayStr);
  }

  /// id + type + date 기반 키
  static String _hiddenKey(Notice n) {
    final datePart = n.date != null ? _dateString(n.date!) : 'nodate';
    return '$_hiddenPrefix${n.id}_${n.type}_$datePart';
  }

  static String _dateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
}

/// --------------------------------------------------
/// 데이터 정의
/// --------------------------------------------------
enum SongCategory { original, cover, collabo, playlist, concert }

String categoryLabel(SongCategory c) {
  switch (c) {
    case SongCategory.original:
      return "오리지널";
    case SongCategory.cover:
      return "커버";
    case SongCategory.collabo:
      return "콜라보 / 의뢰";
    case SongCategory.playlist:
      return "플레이리스트";
    case SongCategory.concert:
      return "콘서트";
  }
}

String categoryFile(SongCategory c) {
  switch (c) {
    case SongCategory.original:
      return "original.json";
    case SongCategory.cover:
      return "cover.json";
    case SongCategory.collabo:
      return "collabo.json";
    case SongCategory.playlist:
      return "playlist.json";
    case SongCategory.concert:
      return "concerts.json";
  }
}

/// 멤버별 폴더 이름
const Map<String, String> memberFolders = {
  "아야츠노 유니": "yuni",
  "네네코 마시로": "mashiro",
  "시라유키 히나": "hina",
  "아카네 리제": "lize",
  "아라하시 타비": "tabi",
  "텐코 시부키": "shibuki",
  "아오쿠모 린": "rin",
  "하나코 나나": "nana",
  "유즈하 리코": "riko",
  "사키하네 후야": "huya",
  "아이리 칸나": "kanna",
  "스텔라이브 채널": "GS",
};

/// --------------------------------------------------
/// Song / Playlist / Concert 모델
/// --------------------------------------------------
class Song {
  final String title;
  final String originalArtist;
  final String? tj;
  final String? tj60;
  final String? tj60mr;
  final String? ky;
  final String? collaboWith;

  Song({
    required this.title,
    required this.originalArtist,
    this.tj,
    this.tj60,
    this.tj60mr,
    this.ky,
    this.collaboWith,
  });

  factory Song.fromJson(dynamic data) {
    final j = (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    String req(v) => (v ?? "").toString();
    String? opt(v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return Song(
      title: req(j["title"]),
      originalArtist: req(j["originalArtist"]),
      tj: opt(j["tj"]),
      tj60: opt(j["tj60"]),
      tj60mr: opt(j["tj60mr"]),
      ky: opt(j["ky"]),
      collaboWith: opt(j["collaboWith"]),
    );
  }
}

class Playlist {
  final String title;
  final List<Song> songs;

  Playlist({required this.title, required this.songs});

  factory Playlist.fromJson(Map<String, dynamic> j) {
    final list = (j["songs"] as List?) ?? [];
    return Playlist(
      title: (j["playlistTitle"] ?? "").toString(),
      songs: list.map((e) => Song.fromJson(e)).toList(),
    );
  }
}

class ConcertPart {
  final String title;
  final List<Song> songs;

  ConcertPart({required this.title, required this.songs});

  factory ConcertPart.fromJson(Map<String, dynamic> j) {
    final list = (j["songs"] as List?) ?? [];
    return ConcertPart(
      title: (j["partTitle"] ?? "").toString(),
      songs: list.map((e) => Song.fromJson(e)).toList(),
    );
  }
}

class Concert {
  final String title;
  final List<ConcertPart> parts;

  Concert({required this.title, required this.parts});

  factory Concert.fromJson(Map<String, dynamic> j) {
    final partsJson = (j["parts"] as List?) ?? [];
    return Concert(
      title: (j["concertTitle"] ?? "").toString(),
      parts: partsJson.map((e) => ConcertPart.fromJson(e)).toList(),
    );
  }
}

// 기본 카테고리(설정 없을 때 사용)
const List<SongCategory> defaultCategories = [
  SongCategory.original,
  SongCategory.cover,
  SongCategory.collabo,
  SongCategory.playlist,
  SongCategory.concert,
];


// JSON -> SongCategory 변환
  //SongCategory? _categoryFromString(String s) {
  //  switch (s) {
  //    case 'original':
  //      return SongCategory.original;
  //    case 'cover':
  //      return SongCategory.cover;
  //    case 'collabo':
  //      return SongCategory.collabo;
  //    case 'playlist':
  //      return SongCategory.playlist;
  //    case 'concert':
  //     return SongCategory.concert;
  //    default:
  //      return null;
  //  }
  //}

/// --------------------------------------------------
/// 멤버별 사용 카테고리 설정 (assets/data/member_categories.json)
/// --------------------------------------------------

Map<String, List<SongCategory>>? _memberCategoriesCache;

/// JSON을 읽어서 "yuni" -> [SongCategory.original, ...] 형태로 변환
Future<Map<String, List<SongCategory>>> _loadMemberCategoryConfig() async {
  final txt = await safeLoadJsonString('assets/data/member_categories.json');
  final raw = jsonDecode(txt);

  final result = <String, List<SongCategory>>{};

  if (raw is Map<String, dynamic>) {
    raw.forEach((key, value) {
      if (value is! List) return;

      final set = <SongCategory>{};

      for (final v in value) {
        final s = v.toString();
        switch (s) {
          case 'original':
            set.add(SongCategory.original);
            break;
          case 'cover':
            set.add(SongCategory.cover);
            break;
          case 'collabo':
            set.add(SongCategory.collabo);
            break;
          case 'playlist':
            set.add(SongCategory.playlist);
            break;
          case 'concert':
            set.add(SongCategory.concert);
            break;
        // 만약 JSON에 mashup을 계속 쓰고 싶다면, 이렇게 playlist로 취급해도 됨
          case 'mashup':
            set.add(SongCategory.playlist);
            break;
        }
      }

      if (set.isNotEmpty) {
        result[key] = set.toList();
      }
    });
  }

  return result;
}

/// UI에서 실제로 쓸 "이 멤버는 어떤 카테고리 버튼을 보여줄까?" 함수
Future<List<SongCategory>> loadAvailableCategories(String memberName) async {
  // 캐시 없으면 한번 로드
  _memberCategoriesCache ??= await _loadMemberCategoryConfig();

  // 화면에 보이는 이름 -> 폴더 이름으로 변환 ("사키하네 후야" -> "huya")
  final folder = memberFolders[memberName];

  // 혹시 매핑이 없으면 기존처럼 전부 다 보여주기
  if (folder == null) {
    return [
      SongCategory.original,
      SongCategory.cover,
      SongCategory.collabo,
      SongCategory.playlist,
      SongCategory.concert,
    ];
  }

  final list = _memberCategoriesCache![folder];

  // 설정에 없으면 마찬가지로 기본 전체 노출
  if (list == null || list.isEmpty) {
    return [
      SongCategory.original,
      SongCategory.cover,
      SongCategory.collabo,
      SongCategory.playlist,
      SongCategory.concert,
    ];
  }

  return list;
}

/// --------------------------------------------------
/// JSON 로딩 함수들
/// --------------------------------------------------
Future<String> safeLoadJsonString(String relativePath) async {
  final String? raw = await RemoteDataManager.loadJsonString(relativePath);

  if (raw == null || raw.trim().isEmpty) {
    return '[]';
  }
  return raw;
}

Future<String> loadMemberJson(String member, SongCategory category) async {
  final folder = memberFolders[member]!;
  return safeLoadJsonString("assets/data/$folder/${categoryFile(category)}");
}

Future<List<Song>> loadSongs(String member, SongCategory c) async {
  final txt = await loadMemberJson(member, c);
  final raw = jsonDecode(txt);
  if (raw is! List) return [];
  return raw.map((e) => Song.fromJson(e)).toList();
}

Future<List<Playlist>> loadPlaylists(String member) async {
  final List<Playlist> result = [];

  // playlist.json
  try {
    final txt = await safeLoadJsonString(
        "assets/data/${memberFolders[member]}/playlist.json");
    final raw = jsonDecode(txt);
    if (raw is List) {
      result.addAll(raw.map((e) => Playlist.fromJson(e)));
    }
  } catch (_) {}

  // mashup.json → playlist 형태로 변환
  try {
    final mtxt = await safeLoadJsonString(
        "assets/data/${memberFolders[member]}/mashup.json");
    final mraw = jsonDecode(mtxt);
    if (mraw is List) {
      for (final m in mraw) {
        final title = (m["mashupTitle"] ?? "").toString();
        final tracks = (m["tracks"] as List?) ?? [];
        result.add(Playlist(
          title: title,
          songs: tracks.map((e) => Song.fromJson(e)).toList(),
        ));
      }
    }
  } catch (_) {}

  return result;
}

Future<List<Concert>> loadConcerts(String member) async {
  final txt = await safeLoadJsonString(
      "assets/data/${memberFolders[member]}/concerts.json");
  final raw = jsonDecode(txt);
  if (raw is! List) return [];
  return raw.map((e) => Concert.fromJson(e)).toList();
}

/// --------------------------------------------------
/// 전체 곡 로딩 (검색 / 즐겨찾기용) + 캐시
/// --------------------------------------------------
List<Song>? _allSongsCache;

Future<List<Song>> loadAllSongs() async {
  if (_allSongsCache != null) {
    return _allSongsCache!;
  }

  final List<Song> list = <Song>[];

  for (final entry in memberFolders.entries) {
    final folder = entry.value;

    // original / cover / collabo
    for (final category in [
      SongCategory.original,
      SongCategory.cover,
      SongCategory.collabo,
    ]) {
      try {
        final txt = await safeLoadJsonString(
            'assets/data/$folder/${categoryFile(category)}');
        final raw = jsonDecode(txt);
        if (raw is! List) continue;
        list.addAll(raw.map((e) => Song.fromJson(e)));
      } catch (_) {}
    }

    // playlist
    try {
      final txt =
      await safeLoadJsonString('assets/data/$folder/playlist.json');
      final raw = jsonDecode(txt);
      if (raw is List) {
        for (final p in raw) {
          final songsJson = (p['songs'] as List?) ?? <dynamic>[];
          list.addAll(songsJson.map((e) => Song.fromJson(e)));
        }
      }
    } catch (_) {}

    // concerts
    try {
      final txt =
      await safeLoadJsonString('assets/data/$folder/concerts.json');
      final raw = jsonDecode(txt);
      if (raw is List) {
        for (final c in raw) {
          final parts = (c['parts'] as List?) ?? <dynamic>[];
          for (final part in parts) {
            final songsJson = (part['songs'] as List?) ?? <dynamic>[];
            list.addAll(songsJson.map((e) => Song.fromJson(e)));
          }
        }
      }
    } catch (_) {}

    // mashup
    try {
      final txt =
      await safeLoadJsonString('assets/data/$folder/mashup.json');
      final raw = jsonDecode(txt);
      if (raw is List) {
        for (final m in raw) {
          final tracksJson = (m['tracks'] as List?) ?? <dynamic>[];
          list.addAll(tracksJson.map((e) => Song.fromJson(e)));
        }
      }
    } catch (_) {}
  }

  _allSongsCache = list;
  return list;
}

/// --------------------------------------------------
/// TJ/KY 표시 (색상 포함)
/// --------------------------------------------------
Widget buildTjKyText(Song s) {
  final spans = <InlineSpan>[];

  spans.add(const TextSpan(text: "TJ: "));

  bool added = false;
  if (s.tj != null && s.tj!.isNotEmpty) {
    spans.add(TextSpan(text: s.tj));
    added = true;
  }
  if (s.tj60 != null && s.tj60!.isNotEmpty) {
    if (added) spans.add(const TextSpan(text: " / "));
    spans.add(TextSpan(
        text: "${s.tj60}(60 시리즈 이상)",
        style: const TextStyle(color: Colors.orange)));
    added = true;
  }
  if (s.tj60mr != null && s.tj60mr!.isNotEmpty) {
    if (added) spans.add(const TextSpan(text: " / "));
    spans.add(TextSpan(
        text: "${s.tj60mr}(MR, 60 시리즈 이상)",
        style: const TextStyle(color: Colors.green)));
    added = true;
  }

  if (!added) spans.add(const TextSpan(text: "-"));

  spans.add(const TextSpan(text: "    KY: "));
  spans.add(TextSpan(text: (s.ky == null || s.ky!.isEmpty) ? "-" : s.ky!));

  return Text.rich(TextSpan(children: spans));
}

/// --------------------------------------------------
/// 공통 SongTile
/// --------------------------------------------------
class SongTile extends StatelessWidget {
  final Song song;
  final bool isFav;
  final void Function(String) toggleFav;

  const SongTile({
    super.key,
    required this.song,
    required this.isFav,
    required this.toggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final artistText =
    song.originalArtist.isEmpty ? '오리지널곡' : song.originalArtist;

    return ListTile(
      title: Text(song.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('원곡: $artistText'),
          if (song.collaboWith != null && song.collaboWith!.isNotEmpty)
            Text('콜라보: ${song.collaboWith}'),
          buildTjKyText(song),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isFav ? Icons.star : Icons.star_border,
          color: Colors.amber,
        ),
        onPressed: () => toggleFav(song.title),
      ),
    );
  }
}

/// --------------------------------------------------
/// 멤버 목록 화면
/// --------------------------------------------------
class MemberListBody extends StatelessWidget {
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const MemberListBody({
    super.key,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final names = memberFolders.keys.toList();

    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberCategoryPage(
                  memberName: name,
                  favorites: favorites,
                  toggleFav: toggleFav,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// --------------------------------------------------
/// 메인 화면 (하단 네비 + 설정 버튼 + 공지 팝업)
/// --------------------------------------------------
class MainScreen extends StatefulWidget {
  final AppTheme currentTheme;
  final void Function(AppTheme) onThemeChanged;

  const MainScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  Set<String> favorites = <String>{};
  final _titles = const ['멤버', '검색', '즐겨찾기'];

  bool _noticeEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadFav();
    _loadNoticeEnabled();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotices();
    });
  }

  void _loadFav() async {
    favorites = await FavoriteManager.load();
    setState(() {});
  }

  void _loadNoticeEnabled() async {
    final enabled = await NoticePrefs.load();
    setState(() {
      _noticeEnabled = enabled;
    });
  }

  /// 메인에서 관리하는 즐겨찾기 토글
  void toggleFav(String title) {
    setState(() {
      if (favorites.contains(title)) {
        favorites.remove(title);
      } else {
        favorites.add(title);
      }
      FavoriteManager.save(favorites);
    });
  }

  /// 공지 팝업 표시
  void _checkNotices() async {
    if (!_noticeEnabled) return;

    final notices = await NoticeManager.loadNotices();
    if (!mounted) return;

    final now = DateTime.now();
    final threshold = now.subtract(const Duration(days: 2)); // 최근 2일

    final recentNotices = notices.where((n) {
      if (n.date == null) return false;
      return !n.date!.isBefore(threshold); // n.date >= threshold
    }).toList();

    for (final n in recentNotices) {
      final hidden = await NoticeManager.isHiddenToday(n);
      if (hidden) continue;

      if (!mounted) return;
      await _showNoticeDialog(n);
    }
  }

  Future<void> _showNoticeDialog(Notice n) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(n.title),
          content: SingleChildScrollView(
            child: Text(n.body),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () async {
                await NoticeManager.hideToday(n);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('오늘 하루 보지 않기'),
            ),
          ],
        );
      },
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SettingsPage(
          initialTheme: widget.currentTheme,
          onThemeChanged: (t) {
            widget.onThemeChanged(t);
          },
          initialNoticeEnabled: _noticeEnabled,
          onNoticeChanged: (enabled) {
            setState(() {
              _noticeEnabled = enabled;
            });
            NoticePrefs.save(enabled);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_index == 0) {
      body = MemberListBody(
        favorites: favorites,
        toggleFav: toggleFav,
      );
    } else if (_index == 1) {
      body = SearchPage(
        favorites: favorites,
        toggleFav: toggleFav,
      );
    } else {
      body = FavoritePage(
        favorites: favorites,
        toggleFav: toggleFav,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          ...buildAppBarActions(context, favorites, toggleFav),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group),
            label: '멤버',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: '검색',
          ),
          NavigationDestination(
            icon: Icon(Icons.star),
            label: '즐겨찾기',
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------
/// 설정 페이지 (테마 + 공지 팝업 ON/OFF)
/// --------------------------------------------------
class SettingsPage extends StatefulWidget {
  final AppTheme initialTheme;
  final void Function(AppTheme) onThemeChanged;
  final bool initialNoticeEnabled;
  final void Function(bool) onNoticeChanged;

  const SettingsPage({
    super.key,
    required this.initialTheme,
    required this.onThemeChanged,
    required this.initialNoticeEnabled,
    required this.onNoticeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppTheme _theme;
  late bool _noticeEnabled;

  @override
  void initState() {
    super.initState();
    _theme = widget.initialTheme;
    _noticeEnabled = widget.initialNoticeEnabled;
  }

  void _setTheme(AppTheme t) {
    setState(() {
      _theme = t;
    });
    widget.onThemeChanged(t); // MyApp에 전달 → 즉시 테마 반영
  }

  void _setNoticeEnabled(bool enabled) {
    setState(() {
      _noticeEnabled = enabled;
    });
    widget.onNoticeChanged(enabled); // MainScreen + SharedPrefs 반영
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              '테마',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<AppTheme>(
            title: const Text('시스템 설정 그대로'),
            value: AppTheme.system,
            groupValue: _theme,
            onChanged: (v) {
              if (v != null) _setTheme(v);
            },
          ),
          RadioListTile<AppTheme>(
            title: const Text('화이트 (밝은 테마)'),
            value: AppTheme.light,
            groupValue: _theme,
            onChanged: (v) {
              if (v != null) _setTheme(v);
            },
          ),
          RadioListTile<AppTheme>(
            title: const Text('블랙 (다크 테마)'),
            value: AppTheme.dark,
            groupValue: _theme,
            onChanged: (v) {
              if (v != null) _setTheme(v);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('공지 팝업 알림'),
            subtitle: const Text('앱 실행 시 공지 창을 띄울지 설정합니다.'),
            value: _noticeEnabled,
            onChanged: _setNoticeEnabled,
          ),
        ],
      ),
    );
  }
}

/// --------------------------------------------------
/// 멤버 → 카테고리 화면 (member_categories.json 기반 + 리제 J-POP Mashup! 특수 처리)
/// --------------------------------------------------
class MemberCategoryPage extends StatelessWidget {
  final String memberName;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const MemberCategoryPage({
    super.key,
    required this.memberName,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final String name = memberName; // 지역 변수로 받아두면 더 안전

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: buildAppBarActions(context, favorites, toggleFav),
      ),
      body: FutureBuilder<List<SongCategory>>(
          future: loadAvailableCategories(memberName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('에러 발생:\n${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return const Center(child: Text('표시할 카테고리가 없습니다.'));
          }

          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final c = categories[index];

              // 🔹 아카네 리제 전용: "플레이리스트" 대신 "J-POP Mashup!" 바로 열기
              if (name == '아카네 리제' && c == SongCategory.playlist) {
                return ListTile(
                  title: const Text('J-POP Mashup!'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    // mashup.json 포함해서 플레이리스트들 로드
                    final playlists = await loadPlaylists(name);

                    if (playlists.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('J-POP Mashup! 데이터가 없습니다.'),
                        ),
                      );
                      return;
                    }

                    // 제목에 'J-POP Mashup' 이 들어간 플레이리스트 찾기
                    Playlist target = playlists.first;
                    for (final p in playlists) {
                      if (p.title.contains('J-POP Mashup')) {
                        target = p;
                        break;
                      }
                    }

                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailPage(
                          playlist: target,
                          favorites: favorites,
                          toggleFav: toggleFav,
                        ),
                      ),
                    );
                  },
                );
              }

              // 🔹 그 외 일반 케이스
              return ListTile(
                title: Text(categoryLabel(c)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (c == SongCategory.playlist) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistListPage(
                          memberName: name,
                          favorites: favorites,
                          toggleFav: toggleFav,
                        ),
                      ),
                    );
                  } else if (c == SongCategory.concert) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConcertListPage(
                          memberName: name,
                          favorites: favorites,
                          toggleFav: toggleFav,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SongListPage(
                          memberName: name,
                          category: c,
                          favorites: favorites,
                          toggleFav: toggleFav,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// --------------------------------------------------
/// 일반 곡 목록
/// --------------------------------------------------
class SongListPage extends StatefulWidget {
  final String memberName;
  final SongCategory category;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const SongListPage({
    super.key,
    required this.memberName,
    required this.category,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  State<SongListPage> createState() => _SongListPageState();
}

class _SongListPageState extends State<SongListPage> {
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favorites};
  }

  void _toggle(String title) {
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
      } else {
        _favorites.add(title);
      }
    });
    widget.toggleFav(title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel(widget.category)),
        actions: buildAppBarActions(context, _favorites, _toggle),
      ),
      body: FutureBuilder<List<Song>>(
        future: loadSongs(widget.memberName, widget.category),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('에러 발생:\n${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final songs = snapshot.data!;
          if (songs.isEmpty) {
            return const Center(child: Text('등록된 곡이 없습니다.'));
          }

          return ListView.separated(
            itemCount: songs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongTile(
                song: song,
                isFav: _favorites.contains(song.title),
                toggleFav: _toggle,
              );
            },
          );
        },
      ),
    );
  }
}

/// --------------------------------------------------
/// 플레이리스트 목록 / 상세
/// --------------------------------------------------
class PlaylistListPage extends StatelessWidget {
  final String memberName;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const PlaylistListPage({
    super.key,
    required this.memberName,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이리스트'),
        actions: buildAppBarActions(context, favorites, toggleFav),
      ),
      body: FutureBuilder<List<Playlist>>(
        future: loadPlaylists(memberName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('에러 발생:\n${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final playlists = snapshot.data!;
          if (playlists.isEmpty) {
            return const Center(child: Text('등록된 플레이리스트가 없습니다.'));
          }

          return ListView.separated(
            itemCount: playlists.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final p = playlists[index];
              return ListTile(
                title: Text(p.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailPage(
                        playlist: p,
                        favorites: favorites,
                        toggleFav: toggleFav,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const PlaylistDetailPage({
    super.key,
    required this.playlist,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favorites};
  }

  void _toggle(String title) {
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
      } else {
        _favorites.add(title);
      }
    });
    widget.toggleFav(title);
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.playlist.songs;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.title),
        actions: buildAppBarActions(context, _favorites, _toggle),
      ),
      body: ListView.separated(
        itemCount: songs.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final s = songs[index];
          return SongTile(
            song: s,
            isFav: _favorites.contains(s.title),
            toggleFav: _toggle,
          );
        },
      ),
    );
  }
}

/// --------------------------------------------------
/// 콘서트 목록 / 전체 곡
/// --------------------------------------------------
class ConcertListPage extends StatelessWidget {
  final String memberName;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const ConcertListPage({
    super.key,
    required this.memberName,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('콘서트'),
        actions: buildAppBarActions(context, favorites, toggleFav),
      ),
      body: FutureBuilder<List<Concert>>(
        future: loadConcerts(memberName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('에러 발생:\n${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final concerts = snapshot.data!;
          if (concerts.isEmpty) {
            return const Center(child: Text('등록된 콘서트가 없습니다.'));
          }

          return ListView.separated(
            itemCount: concerts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final c = concerts[index];
              return ListTile(
                title: Text(c.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConcertSongsPage(
                        concert: c,
                        favorites: favorites,
                        toggleFav: toggleFav,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ConcertSongsPage extends StatefulWidget {
  final Concert concert;
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const ConcertSongsPage({
    super.key,
    required this.concert,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  State<ConcertSongsPage> createState() => _ConcertSongsPageState();
}

class _ConcertSongsPageState extends State<ConcertSongsPage> {
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favorites};
  }

  void _toggle(String title) {
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
      } else {
        _favorites.add(title);
      }
    });
    widget.toggleFav(title);
  }

  @override
  Widget build(BuildContext context) {
    final items = <Map<String, dynamic>>[];

    for (final part in widget.concert.parts) {
      if (part.songs.isEmpty) continue;

      items.add({
        'type': 'header',
        'title': part.title,
      });

      for (final song in part.songs) {
        items.add({
          'type': 'song',
          'song': song,
        });
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.concert.title),
        actions: buildAppBarActions(context, _favorites, _toggle),
      ),
      body: items.isEmpty
          ? const Center(child: Text('등록된 곡이 없습니다.'))
          : ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) =>
        const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          if (item['type'] == 'header') {
            final title = item['title'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            final song = item['song'] as Song;
            return SongTile(
              song: song,
              isFav: _favorites.contains(song.title),
              toggleFav: _toggle,
            );
          }
        },
      ),
    );
  }
}

/// --------------------------------------------------
/// 즐겨찾기 화면 (드래그로 순서 변경 가능)
/// --------------------------------------------------
class FavoritePage extends StatefulWidget {
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const FavoritePage({
    super.key,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  late Set<String> _favorites;
  List<String> _orderedTitles = <String>[];
  bool _loadingOrder = true;

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favorites};
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final order = await FavoriteManager.loadOrder(_favorites);
    setState(() {
      _orderedTitles = order;
      _loadingOrder = false;
    });
  }

  void _toggle(String title) {
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
        _orderedTitles.remove(title);
      } else {
        _favorites.add(title);
        _orderedTitles.add(title);
      }
    });
    FavoriteManager.save(_favorites);
    widget.toggleFav(title);
    FavoriteManager.saveOrder(_orderedTitles);
  }

  @override
  Widget build(BuildContext context) {
    if (_favorites.isEmpty) {
      return const Center(child: Text('즐겨찾기한 곡이 없습니다.'));
    }

    if (_loadingOrder) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<Song>>(
      future: loadAllSongs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(
              child: Text('에러 발생:\n${snapshot.error}'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        final allSongs = snapshot.data!;

        final Map<String, Song> songByTitle = {};
        for (final s in allSongs) {
          songByTitle[s.title] = s;
        }

        _orderedTitles =
            _orderedTitles.where((t) => songByTitle.containsKey(t)).toList();

        if (_orderedTitles.isEmpty) {
          return const Center(child: Text('즐겨찾기한 곡 데이터가 없습니다.'));
        }

        return ReorderableListView.builder(
          itemCount: _orderedTitles.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _orderedTitles.removeAt(oldIndex);
              _orderedTitles.insert(newIndex, item);
            });
            FavoriteManager.saveOrder(_orderedTitles);
          },
          itemBuilder: (context, index) {
            final title = _orderedTitles[index];
            final song = songByTitle[title];
            if (song == null) {
              return ListTile(
                key: ValueKey('missing_$title'),
                title: Text('$title (데이터 없음)'),
              );
            }
            return Container(
              key: ValueKey(title),
              child: SongTile(
                song: song,
                isFav: _favorites.contains(song.title),
                toggleFav: _toggle,
              ),
            );
          },
        );
      },
    );
  }
}

/// --------------------------------------------------
/// 검색 화면
/// --------------------------------------------------
class SearchPage extends StatefulWidget {
  final Set<String> favorites;
  final void Function(String) toggleFav;

  const SearchPage({
    super.key,
    required this.favorites,
    required this.toggleFav,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Song> _allSongs = <Song>[];
  List<Song> _filtered = <Song>[];
  bool _loading = true;
  late Set<String> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favorites};
    _loadAll();
  }

  void _loadAll() async {
    _allSongs = await loadAllSongs();
    setState(() => _loading = false);
  }

  void _onSearch(String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = <Song>[]);
      return;
    }

    final filtered = _allSongs.where((s) {
      final title = s.title.toLowerCase();
      final artist = s.originalArtist.toLowerCase();
      return title.contains(q) ||
          artist.contains(q) ||
          (s.tj?.contains(q) ?? false) ||
          (s.tj60?.contains(q) ?? false) ||
          (s.tj60mr?.contains(q) ?? false) ||
          (s.ky?.contains(q) ?? false);
    }).toList();

    final Map<String, Song> unique = {};
    for (final s in filtered) {
      final key =
          '${s.title}::${s.originalArtist}::${s.tj ?? ""}::${s.tj60 ?? ""}::${s.tj60mr ?? ""}::${s.ky ?? ""}';
      unique[key] = s;
    }

    setState(() {
      _filtered = unique.values.toList();
    });
  }

  void _toggle(String title) {
    setState(() {
      if (_favorites.contains(title)) {
        _favorites.remove(title);
      } else {
        _favorites.add(title);
      }
    });
    widget.toggleFav(title);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: '곡 제목 / 가수 / 번호 검색',
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearch,
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('검색 결과가 없습니다.'))
              : ListView.separated(
            itemCount: _filtered.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final s = _filtered[index];
              return SongTile(
                song: s,
                isFav: _favorites.contains(s.title),
                toggleFav: _toggle,
              );
            },
          ),
        ),
      ],
    );
  }
}
