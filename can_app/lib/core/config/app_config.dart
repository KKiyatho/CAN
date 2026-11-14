/// 빌드 시 `--dart-define`으로 환경별 값을 교체할 수 있다.
/// 기본값은 운영 환경의 공개 식별자이며 관리자 비밀키는 포함하지 않는다.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xlqqeypfomtvkxeyyxek.supabase.co',
  );

  /// 클라이언트에 공개되는 publishable key. 접근 제어는 DB의 RLS가 담당한다.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_VVPXLJBHNaZaaub6-RlgNg_Q7wa5B0Z',
  );

  static const recommendUrl = String.fromEnvironment(
    'CAN_RECOMMEND_URL',
    defaultValue: 'https://can-api-55425.azurewebsites.net/api/recommend',
  );

  static const webAppUrl = String.fromEnvironment(
    'CAN_WEB_URL',
    defaultValue: 'https://canweb125962.z7.web.core.windows.net/',
  );

  /// Android/iOS 앱에 등록된 OAuth 복귀 주소.
  static const oauthRedirectUrl = 'can://login-callback';
}
