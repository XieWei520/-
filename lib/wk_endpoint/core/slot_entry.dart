import 'package:meta/meta.dart';

typedef SlotPredicate<TContext> = bool Function(TContext context);
typedef SlotBuilder<TContext, TPayload> = TPayload Function(TContext context);

@immutable
class SlotEntry<TContext, TPayload> {
  const SlotEntry({
    required this.id,
    required this.build,
    this.priority = 0,
    this.predicate,
  });

  final String id;
  final int priority;
  final SlotPredicate<TContext>? predicate;
  final SlotBuilder<TContext, TPayload> build;

  bool matches(TContext context) => predicate?.call(context) ?? true;
}
