import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/local_media_image_provider_io.dart';

void main() {
  test('resolves plain local paths and file uris to FileImage providers', () {
    final pathProvider = resolveLocalMediaImageProvider(' C:/media/photo.png ');
    final uriProvider = resolveLocalMediaImageProvider(
      'file:///C:/media/photo.png',
    );

    expect(pathProvider, isA<FileImage>());
    expect((pathProvider! as FileImage).file.path, 'C:/media/photo.png');
    expect(uriProvider, isA<FileImage>());
  });

  test('rejects blank and remote media urls', () {
    expect(resolveLocalMediaImageProvider('   '), isNull);
    expect(
      resolveLocalMediaImageProvider('https://example.com/photo.png'),
      isNull,
    );
    expect(
      resolveLocalMediaImageProvider('http://example.com/photo.png'),
      isNull,
    );
    expect(
      resolveLocalMediaImageProvider('data:image/png;base64,AA=='),
      isNull,
    );
  });
}
