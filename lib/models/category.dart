import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  String name;
  int colorValue;
  String iconKey;
  /// where this category applies: tasks, transactions, habits, notes
  Set<String> scopes;
  /// User-defined ordering. Lower values come first within a scope.
  int sortIndex;

  CategoryModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconKey,
    required this.scopes,
    this.sortIndex = 0,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconKey': iconKey,
        'scopes': scopes.toList(),
        'sortIndex': sortIndex,
      };

  factory CategoryModel.fromJson(Map j) => CategoryModel(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: (j['colorValue'] as num).toInt(),
        iconKey: j['iconKey'] as String,
        scopes: ((j['scopes'] as List?)?.map((e) => e.toString()) ?? const [])
            .toSet(),
        sortIndex: (j['sortIndex'] as num?)?.toInt() ?? 0,
      );
}

/// Map of icon keys -> emoji. Keeps it light and avoids extra icon packs.
class CategoryIcons {
  static const Map<String, String> all = {
    'shopping_cart': '🛒',
    'fastfood': '🍔',
    'coffee': '☕',
    'restaurant': '🍽️',
    'transport': '🚌',
    'taxi': '🚕',
    'fuel': '⛽',
    'home': '🏠',
    'utility': '💡',
    'entertainment': '🎬',
    'sport': '🏋️',
    'health': '💊',
    'pharmacy': '💊',
    'pet': '🐶',
    'gift': '🎁',
    'travel': '✈️',
    'education': '📚',
    'work': '💼',
    'salary': '💰',
    'transfer': '💳',
    'other': '📦',
    'savings': '🏦',
    'subscription': '📺',
    'kids': '🧒',
    'beauty': '💅',
  };

  static String resolve(String key) => all[key] ?? '📦';
}
