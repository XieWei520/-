import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/video_call/multi_value_listenable_rebuilder.dart';

void main() {
  testWidgets('rebuilds child when any listened value changes', (tester) async {
    final first = ValueNotifier<Object?>(0);
    final second = ValueNotifier<Object?>(0);
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MultiValueListenableRebuilder(
          listenables: <ValueListenable<Object?>>[first, second],
          builder: (context) {
            buildCount++;
            return Text(
              '${first.value}-${second.value}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );

    expect(find.text('0-0'), findsOneWidget);
    expect(buildCount, 1);

    first.value = 1;
    await tester.pump();

    expect(find.text('1-0'), findsOneWidget);
    expect(buildCount, 2);

    second.value = 3;
    await tester.pump();

    expect(find.text('1-3'), findsOneWidget);
    expect(buildCount, 3);
  });
}
