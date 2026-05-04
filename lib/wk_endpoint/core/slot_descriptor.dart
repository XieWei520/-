import 'package:meta/meta.dart';

@immutable
class SlotDescriptor<TContext, TPayload> {
  const SlotDescriptor(this.name)
      : contextType = TContext,
        payloadType = TPayload;

  final String name;
  final Type contextType;
  final Type payloadType;

  @override
  bool operator ==(Object other) {
    return other is SlotDescriptor &&
        other.name == name &&
        other.contextType == contextType &&
        other.payloadType == payloadType;
  }

  @override
  int get hashCode => Object.hash(name, contextType, payloadType);

  @override
  String toString() => 'SlotDescriptor($name)';
}
