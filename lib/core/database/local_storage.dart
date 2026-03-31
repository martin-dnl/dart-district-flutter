import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
  }

  static Future<Box<T>> openBox<T>(String name) async {
    return Hive.openBox<T>(name);
  }

  static Future<void> put<T>(String boxName, String key, T value) async {
    final box = await Hive.openBox<T>(boxName);
    await box.put(key, value);
  }

  static Future<T?> get<T>(String boxName, String key) async {
    final box = await Hive.openBox<T>(boxName);
    return box.get(key);
  }

  static Future<void> remove(String boxName, String key) async {
    final box = await Hive.openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = await Hive.openBox(boxName);
    await box.clear();
  }
}
