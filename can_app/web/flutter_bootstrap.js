{{flutter_js}}
{{flutter_build_config}}

// 부트스트랩뿐 아니라 앱 코드 URL도 갱신하여 구버전 캐시를 우회한다.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?v=20261111-i18n1';
  }
}
Promise.resolve(window.canCacheReady).then(function () {
  return _flutter.loader.load();
});