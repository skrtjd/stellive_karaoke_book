import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// GitHub Raw(원격) -> 실패 시 로컬 assets fallback 로더
class RemoteDataManager {
  RemoteDataManager._();

  /// ✅ 네 실제 저장소에 맞춘 baseUrl
  /// https://github.com/skrtjd/stellive_karaoke_app_data (public, main)
  static String baseUrl =
      'https://raw.githubusercontent.com/skrtjd/stellive_karaoke_app_data/main/';

  static bool _inited = false;

  static Future<void> init({String? overrideBaseUrl}) async {
    if (_inited) return;
    if (overrideBaseUrl != null && overrideBaseUrl.trim().isNotEmpty) {
      baseUrl = overrideBaseUrl.trim();
      if (!baseUrl.endsWith('/')) baseUrl = '$baseUrl/';
    }
    _inited = true;
  }

  /// relativePath 예:
  /// - assets/data/yuni/original.json
  /// - assets/data/member_categories.json
  /// - notices.json (원격에도 같은 위치에 있어야 원격에서 받음)
  static Future<String?> loadJsonString(String relativePath) async {
    final path = _normalizePath(relativePath);

    // 1) 원격 시도
    final remote = await _tryFetchRemote(path);
    if (remote != null) return remote;

    // 2) 로컬 assets fallback
    final local = await _tryLoadAsset(path);
    return local;
  }

  static String _normalizePath(String p) {
    var s = p.trim();
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    return s;
  }

  static Future<String?> _tryFetchRemote(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return utf8.decode(res.bodyBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _tryLoadAsset(String path) async {
    try {
      final txt = await rootBundle.loadString(path);
      if (txt.trim().isEmpty) return null;
      return txt;
    } catch (_) {
      return null;
    }
  }
}
