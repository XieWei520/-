import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_descriptor.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';

void main() {
  const demoSlot = SlotDescriptor<int, String>('demo.slot');
  const sameNameStringSlot = SlotDescriptor<int, String>('same.name.slot');
  const sameNameIntSlot = SlotDescriptor<int, int>('same.name.slot');

  test('registry resolves matching entries by priority descending', () {
    final registry = SlotRegistry();

    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'late',
        priority: 10,
        build: _lateBuilder,
      ),
    );
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'even-only',
        priority: 50,
        predicate: _evenOnly,
        build: _evenBuilder,
      ),
    );
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'first',
        priority: 100,
        build: _firstBuilder,
      ),
    );

    expect(registry.resolve(demoSlot, 1), <String>['first:1', 'late:1']);
    expect(registry.resolve(demoSlot, 2), <String>[
      'first:2',
      'even:2',
      'late:2',
    ]);
  });

  test('registry keeps same-name slots isolated by generic types', () {
    final registry = SlotRegistry();

    registry.register(
      sameNameStringSlot,
      const SlotEntry<int, String>(id: 'string', build: _firstBuilder),
    );
    registry.register(
      sameNameIntSlot,
      const SlotEntry<int, int>(id: 'int', build: _doubleBuilder),
    );

    expect(registry.resolve(sameNameStringSlot, 3), <String>['first:3']);
    expect(registry.resolve(sameNameIntSlot, 3), <int>[6]);
  });

  test(
    'registry keeps same-name slots isolated when descriptors are widened',
    () {
      final registry = SlotRegistry();

      const typedStringSlot = SlotDescriptor<int, String>('same.widened.slot');
      const typedIntSlot = SlotDescriptor<int, int>('same.widened.slot');

      final SlotDescriptor<Object, Object> widenedStringSlot = typedStringSlot;
      final SlotDescriptor<Object, Object> widenedIntSlot = typedIntSlot;

      registry.register(
        widenedStringSlot,
        SlotEntry<Object, Object>(
          id: 'string',
          build: (context) => 'first:$context',
        ),
      );
      registry.register(
        widenedIntSlot,
        const SlotEntry<Object, Object>(id: 'int', build: _constantInt),
      );

      expect(registry.resolve(widenedStringSlot, 3), <Object>['first:3']);
      expect(registry.resolve(widenedIntSlot, 3), <Object>[2]);
    },
  );

  test('equal priority keeps registration order', () {
    final registry = SlotRegistry();

    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'first-equal',
        priority: 50,
        build: _constantA,
      ),
    );
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'second-equal',
        priority: 50,
        build: _constantB,
      ),
    );

    expect(registry.resolve(demoSlot, 0), <String>['a', 'b']);
  });

  test('scope disposal only removes entries owned by that scope', () {
    final registry = SlotRegistry();
    final firstScope = registry.scope('scope:first');
    final secondScope = registry.scope('scope:second');

    firstScope.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'first', build: _constantA),
    );
    secondScope.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'second', build: _constantB),
    );

    expect(registry.resolve(demoSlot, 0), <String>['a', 'b']);

    firstScope.dispose();

    expect(registry.resolve(demoSlot, 0), <String>['b']);
  });

  test('containsId supports idempotent installers', () {
    final registry = SlotRegistry();

    void installOnce() {
      if (registry.containsId(demoSlot, 'one')) {
        return;
      }
      registry.register(
        demoSlot,
        const SlotEntry<int, String>(id: 'one', build: _constantA),
      );
    }

    installOnce();
    installOnce();

    expect(registry.containsId(demoSlot, 'one'), isTrue);
    expect(registry.containsId(demoSlot, 'two'), isFalse);
    expect(registry.resolve(demoSlot, 0), <String>['a']);
  });

  test('stale registration disposal does not clear newer registrations', () {
    final registry = SlotRegistry();
    final firstScope = registry.scope('scope:first');
    final stale = firstScope.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'old', build: _constantA),
    );

    firstScope.dispose();

    registry.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'new', build: _constantB),
    );

    stale.dispose();

    expect(registry.resolve(demoSlot, 0), <String>['b']);
  });
}

String _lateBuilder(int value) => 'late:$value';
String _evenBuilder(int value) => 'even:$value';
bool _evenOnly(int value) => value.isEven;
String _firstBuilder(int value) => 'first:$value';
int _doubleBuilder(int value) => value * 2;
String _constantA(int _) => 'a';
String _constantB(int _) => 'b';
int _constantInt(Object _) => 2;
