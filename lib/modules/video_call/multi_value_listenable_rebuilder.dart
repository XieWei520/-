import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class MultiValueListenableRebuilder extends StatefulWidget {
  const MultiValueListenableRebuilder({
    super.key,
    required this.listenables,
    required this.builder,
  });

  final Iterable<Listenable> listenables;
  final WidgetBuilder builder;

  @override
  State<MultiValueListenableRebuilder> createState() =>
      _MultiValueListenableRebuilderState();
}

class _MultiValueListenableRebuilderState
    extends State<MultiValueListenableRebuilder> {
  void _handleValueChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bind(widget.listenables);
  }

  @override
  void didUpdateWidget(covariant MultiValueListenableRebuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unbind(oldWidget.listenables);
    _bind(widget.listenables);
  }

  @override
  void dispose() {
    _unbind(widget.listenables);
    super.dispose();
  }

  void _bind(Iterable<Listenable> listenables) {
    for (final listenable in listenables) {
      listenable.addListener(_handleValueChanged);
    }
  }

  void _unbind(Iterable<Listenable> listenables) {
    for (final listenable in listenables) {
      listenable.removeListener(_handleValueChanged);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
