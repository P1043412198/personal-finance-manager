import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/models/category.dart';
import 'package:personal_finance/models/goal.dart';

/// Pure helper that mirrors `AppState.reorderCategories` / `reorderGoals`
/// list-mutation semantics so we can verify the "drag from oldIndex to
/// newIndex" math without booting Hive.
List<T> reorderHelper<T>(List<T> source, int oldIndex, int newIndex) {
  final list = List<T>.from(source);
  if (newIndex > oldIndex) newIndex -= 1;
  if (oldIndex < 0 || oldIndex >= list.length) return list;
  if (newIndex < 0 || newIndex >= list.length) return list;
  final moved = list.removeAt(oldIndex);
  list.insert(newIndex, moved);
  return list;
}

void main() {
  group('reorder semantics', () {
    test('moving down adjusts newIndex', () {
      final names = ['a', 'b', 'c', 'd'];
      // ReorderableListView passes newIndex=3 when dragging item 0 to slot 2.
      final result = reorderHelper(names, 0, 3);
      expect(result, ['b', 'c', 'a', 'd']);
    });

    test('moving up keeps newIndex', () {
      final names = ['a', 'b', 'c', 'd'];
      final result = reorderHelper(names, 3, 1);
      expect(result, ['a', 'd', 'b', 'c']);
    });

    test('no-op when indices are out of range', () {
      expect(reorderHelper(['a', 'b'], -1, 0), ['a', 'b']);
      expect(reorderHelper(['a', 'b'], 5, 0), ['a', 'b']);
    });

    test('CategoryModel persists sortIndex through json round-trip', () {
      final c = CategoryModel(
        id: '1',
        name: 'Food',
        colorValue: 0xFF000000,
        iconKey: 'shopping_cart',
        scopes: {'tx'},
        sortIndex: 7,
      );
      final round = CategoryModel.fromJson(c.toJson());
      expect(round.sortIndex, 7);
    });

    test('GoalModel persists sortIndex through json round-trip', () {
      final g = GoalModel(
        id: 'g1',
        name: 'Vacation',
        target: 1000,
        createdAt: DateTime(2026, 1, 1),
        sortIndex: 3,
      );
      final round = GoalModel.fromJson(g.toJson());
      expect(round.sortIndex, 3);
      // Also defaults to 0 when missing.
      final j = g.toJson()..remove('sortIndex');
      final round2 = GoalModel.fromJson(j);
      expect(round2.sortIndex, 0);
    });
  });
}
