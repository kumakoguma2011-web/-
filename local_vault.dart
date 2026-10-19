import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/career.dart';

class LocalVault {
  final _s = const FlutterSecureStorage();
  String _scope = 'guest';

  String _encodeScope(String value) => base64UrlEncode(utf8.encode(value.toLowerCase())).replaceAll('=', '');
  void setUserScope(String userKey) {
    _scope = _encodeScope(userKey);
  }

  String _key(String name) => 'career_ai_${_scope}_$name';
  String _profileKey() => _key('profile');
  String _rulesKey() => _key('rules');
  String _settingsKey() => _key('settings');
  String _suggestionsKey() => _key('profile_suggestions');

  Future<void> saveProfile(ProfileData p) => _s.write(key: _profileKey(), value: jsonEncode(p.toJson()));
  Future<ProfileData?> readProfile() async {
    final v = await _s.read(key: _profileKey());
    return v == null ? null : ProfileData.fromJson(jsonDecode(v));
  }
  Future<void> saveRules(List<AnonRule> rules) => _s.write(
    key: _rulesKey(),
    value: jsonEncode(rules.map((x) => {'id': x.id, 'original': x.original, 'label': x.label}).toList()),
  );
  Future<List<AnonRule>> readRules() async {
    final v = await _s.read(key: _rulesKey());
    if (v == null) return [];
    return (jsonDecode(v) as List).map((x) => AnonRule.fromJson(Map<String, dynamic>.from(x))).toList();
  }
  Future<void> saveSettings(bool zeroContext, String tone, int step) => _s.write(
    key: _settingsKey(),
    value: jsonEncode({'zero_context': zeroContext, 'tone': tone, 'step': step}),
  );
  Future<Map<String, dynamic>> readSettings() async {
    final v = await _s.read(key: _settingsKey());
    return v == null ? <String, dynamic>{'zero_context': false, 'tone': '優しく励ます', 'step': 1} : Map<String, dynamic>.from(jsonDecode(v));
  }

  Future<void> saveProfileSuggestion(ProfileSuggestionRecord record) async {
    final current = await readProfileSuggestions();
    current.insert(0, record);
    if (current.length > 30) current.removeRange(30, current.length);
    await _s.write(key: _suggestionsKey(), value: jsonEncode(current.map((x)=>x.toJson()).toList()));
  }
  Future<List<ProfileSuggestionRecord>> readProfileSuggestions() async {
    final v = await _s.read(key: _suggestionsKey());
    if (v == null) return [];
    return (jsonDecode(v) as List).map((x)=>ProfileSuggestionRecord.fromJson(Map<String,dynamic>.from(x))).toList();
  }

  Future<void> clearAll() async {
    await Future.wait([_s.delete(key: _profileKey()), _s.delete(key: _rulesKey()), _s.delete(key: _settingsKey()), _s.delete(key: _suggestionsKey())]);
  }
}
