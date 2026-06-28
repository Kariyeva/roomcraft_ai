import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_item.dart';

class CustomItemsService {
  static const String _storageKey = 'roomcraft_custom_items';

  static Future<List<CustomItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final List decoded = jsonDecode(raw);

    return decoded
        .map((e) => CustomItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveItem(CustomItem item) async {
    final prefs = await SharedPreferences.getInstance();

    final items = await getItems();

    items.add(item);

    final json = jsonEncode(items.map((e) => e.toJson()).toList());

    await prefs.setString(_storageKey, json);
  }

  static Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final items = await getItems();

    items.removeWhere((e) => e.id == id);

    final json = jsonEncode(items.map((e) => e.toJson()).toList());

    await prefs.setString(_storageKey, json);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
