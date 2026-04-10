import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  static Future<Box<dynamic>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<dynamic>(name);
    }
    return Hive.openBox<dynamic>(name);
  }

  static Future<Box<dynamic>> openBox<T>(String name) async {
    return _openBox(name);
  }

  static Future<void> put<T>(String boxName, String key, T value) async {
    final box = await _openBox(boxName);
    await box.put(key, value);
  }

  static Future<T?> get<T>(String boxName, String key) async {
    final box = await _openBox(boxName);
    final value = box.get(key);
    if (value == null) {
      return null;
    }
    if (value is T) {
      return value;
    }
    return null;
  }

  static Future<void> remove(String boxName, String key) async {
    final box = await _openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = await _openBox(boxName);
    await box.clear();
  }
}
