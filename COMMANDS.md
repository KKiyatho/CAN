# CAN 운영·개발 명령어

모든 명령은 PowerShell 기준이다.

## 앱 개발

```powershell
cd can_app
flutter pub get
flutter run -d chrome          # 웹
flutter run -d <device_id>     # 연결된 Android/iOS 기기
flutter analyze
flutter test
```

환경별 설정은 `--dart-define`으로 바꾼다(기본값은 운영 환경의 공개 식별자).

| 키 | 용도 |
|----|------|
| `SUPABASE_URL` | Supabase 프로젝트 URL |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key (공개용, 비밀키 아님) |
| `CAN_RECOMMEND_URL` | 감정 추천 API 주소 |
| `CAN_WEB_URL` | 웹 앱 주소(데스크톱 QR 안내용) |

## 데이터베이스 (Supabase)

1. Supabase SQL Editor에서 `supabase/migrations/20261114000000_community.sql` 전체를 실행한다
   (또는 Supabase CLI의 `supabase db push`).
2. Authentication > Sign In / Providers에서 **Email**, **Anonymous sign-ins**, **Google**을 켠다.
3. Authentication > URL Configuration의 Redirect URLs에 다음을 추가한다.
   - 웹 운영 주소: `https://canweb125962.z7.web.core.windows.net`
   - 모바일 앱: `can://login-callback`
4. 운영 전 Authentication > Attack Protection에서 CAPTCHA를 켜고, Rate Limits를 확인한다.

## API (Azure Functions)

필수 애플리케이션 설정(Function App > Environment variables):

| 이름 | 설명 |
|------|------|
| `AOAI_ENDPOINT` | Azure OpenAI 엔드포인트 (`https://<resource>.cognitiveservices.azure.com`) |
| `AOAI_DEPLOYMENT` | 배포 이름 (기본 `gpt-4-1-nano`) |
| `SUPABASE_URL` | 사용자 토큰 검증에 쓰는 Supabase URL |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key |
| `ALLOWED_ORIGINS` | 브라우저에서 접근을 허용할 Origin, 쉼표 구분 (예: `https://canweb125962.z7.web.core.windows.net`) |

선택: `RATE_LIMIT_IP_PER_MINUTE`(30), `RATE_LIMIT_USER_PER_MINUTE`(8), `RATE_LIMIT_USER_PER_DAY`(80), `RATE_LIMIT_ANONYMOUS_PER_DAY`(30).

Function App의 관리 ID에는 Azure OpenAI 리소스의 `Cognitive Services OpenAI User` 역할이 필요하다.
호출은 Supabase 로그인 토큰이 있어야 하며 `GET /api/health`로 상태를 확인할 수 있다.
요청 제한은 인스턴스 메모리 기준이므로, 인스턴스를 여러 개로 확장하면 Azure API Management 등 앞단 제한을 함께 둔다.

```powershell
cd api
npm ci
npm test
func azure functionapp publish can-api-55425
```

## 웹 배포 (Azure Storage 정적 웹사이트)

```powershell
cd can_app
flutter build web --release
az storage blob upload-batch --account-name canweb125962 --source .\build\web --destination '$web' --overwrite --auth-mode key
```

배포 후 `main.dart.js`의 해시가 빌드 결과와 같은지 확인한다.

## Android 릴리스 (Google Play)

1. 업로드 키를 만든다(분실하면 복구가 어려우니 안전한 곳에 백업).

   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\can-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias can
   ```

2. `can_app/android/key.properties`를 만든다(저장소에 커밋되지 않음).

   ```properties
   storeFile=C:/Users/<사용자>/can-upload.jks
   storePassword=<비밀번호>
   keyAlias=can
   keyPassword=<비밀번호>
   ```

3. 빌드한다. `key.properties`가 없으면 릴리스 빌드는 의도적으로 실패한다.
   빌드 PC에 Android SDK **cmdline-tools**가 설치되어 있어야 하며(`flutter doctor`로 확인, `flutter doctor --android-licenses`),
   없으면 `appbundle` 빌드가 "failed to strip debug symbols"로 실패한다.

   ```powershell
   cd can_app
   flutter build appbundle --release
   ```

스토어 제출 전에 개인정보 처리방침 URL과 데이터 보안 양식(수집 항목: 이메일, 프로필, 게시글)을 준비한다.
앱 내 계정 삭제는 프로필 시트에서 제공한다.

## iOS 릴리스

macOS에서 Xcode로 서명 팀을 설정한 뒤 `flutter build ipa --release`를 실행한다.
알림 권한 문구와 개인정보 처리방침 URL은 App Store Connect에 입력한다.

## 명언 데이터 갱신

`api/scripts/generate-seed.js`는 AI로 후보를 생성하는 수동 도구다.
생성된 문구는 출처를 사람이 검수한 뒤 `can_app/assets/quotes_curated.json`과 `api/data/quotes.json`에 반영한다.

```powershell
cd api
$env:AOAI_ENDPOINT = 'https://<resource>.cognitiveservices.azure.com'
$env:AOAI_KEY = '<키>'
node scripts/generate-seed.js
```
