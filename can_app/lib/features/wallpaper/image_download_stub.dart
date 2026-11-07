import 'dart:typed_data';

/// 웹이 아닌 플랫폼에서는 사용하지 않는다.
void downloadPng(Uint8List bytes, String filename) {
  throw UnsupportedError('웹에서만 지원됩니다.');
}
