// ============================================================
// Firebase 설정 파일 (FlutterFire CLI로 자동 생성)
//
// 아직 Firebase를 설정하지 않았다면 다음 단계를 따르세요:
//
// 1. Firebase 콘솔에서 프로젝트 생성
//    https://console.firebase.google.com
//
// 2. FlutterFire CLI 설치 및 실행
//    dart pub global activate flutterfire_cli
//    flutterfire configure
//
// 3. 위 명령 실행 후 이 파일이 자동으로 채워집니다.
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          '이 플랫폼은 현재 지원되지 않습니다. flutterfire configure를 실행하세요.',
        );
    }
  }

  // TODO: flutterfire configure 실행 후 아래 값들이 자동으로 채워집니다.
  // 아래는 Firebase 설정 전 플레이스홀더입니다.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCPEUqYdaOkrlT6cSCSbzgWwglY6YZ4VpA',
    appId: '1:274239019801:web:9f0918de77e6ec0b5f4388',
    messagingSenderId: '274239019801',
    projectId: 'vibe-coding-1-abec4',
    authDomain: 'vibe-coding-1-abec4.firebaseapp.com',
    storageBucket: 'vibe-coding-1-abec4.firebasestorage.app',
    measurementId: 'G-6F7R8LW0TV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCXK5O5CzSiyCYHnQgPUzQory_d_a5PG4Y',
    appId: '1:274239019801:android:b68a2059819cd77e5f4388',
    messagingSenderId: '274239019801',
    projectId: 'vibe-coding-1-abec4',
    storageBucket: 'vibe-coding-1-abec4.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCg46elVqAnrLCcCatox330V5CORMt66wI',
    appId: '1:274239019801:ios:42bbb57f848fc6f45f4388',
    messagingSenderId: '274239019801',
    projectId: 'vibe-coding-1-abec4',
    storageBucket: 'vibe-coding-1-abec4.firebasestorage.app',
    iosBundleId: 'com.can.canApp',
  );
}
