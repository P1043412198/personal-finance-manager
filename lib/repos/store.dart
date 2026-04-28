import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Generic JSON-string Hive box wrapper. Keeps things simple — no codegen.
class JsonStore<T> {
  final String boxName;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map) fromJson;
  final String Function(T) idOf;

  Box<String>? _box;

  JsonStore({
    required this.boxName,
    required this.toJson,
    required this.fromJson,
    required this.idOf,
  });

  Future<void> open() async {
    _box = await Hive.openBox<String>(boxName);
  }

  Box<String> get box => _box!;

  List<T> all() {
    return box.values.map((s) => fromJson(jsonDecode(s) as Map)).toList();
  }

  T? get(String id) {
    final s = box.get(id);
    if (s == null) return null;
    return fromJson(jsonDecode(s) as Map);
  }

  Future<void> put(T value) async {
    await box.put(idOf(value), jsonEncode(toJson(value)));
  }

  Future<void> putAll(Iterable<T> values) async {
    final m = <String, String>{
      for (final v in values) idOf(v): jsonEncode(toJson(v)),
    };
    await box.putAll(m);
  }

  Future<void> delete(String id) => box.delete(id);

  Future<void> clear() => box.clear();
}

/// Plain key-value box (for habit logs, prefs, etc.)
class KvStore {
  final String boxName;
  Box? _box;

  KvStore(this.boxName);

  Future<void> open() async {
    _box = await Hive.openBox(boxName);
  }

  Box get box => _box!;

  Iterable<dynamic> get keys => box.keys;
  dynamic get(String key) => box.get(key);
  Future<void> put(String key, dynamic value) => box.put(key, value);
  Future<void> delete(String key) => box.delete(key);
  Future<void> clear() => box.clear();
}
