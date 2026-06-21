# CAN 앱 개발 명령어 모음

## 📦 의존성

```powershell
cd can_app
flutter pub get
```

---

## 🌐 웹 (Chrome) 테스트

```powershell
cd can_app
flutter run -d chrome
```

> ⚠️ 웹 미지원 기능: 로컬 알람 알림, 갤러리 저장 (모바일 전용)

**핫 리스타트** (실행 중 터미널에서): `R`  
**종료**: `q`

### 운영 웹사이트 (Azure 배포)

- URL: https://canweb125962.z7.web.core.windows.net/
- 로그인/프로필 확인 주소: https://canweb125962.z7.web.core.windows.net/

```powershell
# 브라우저로 바로 열기
start https://canweb125962.z7.web.core.windows.net/

# 상태 확인
curl -I https://canweb125962.z7.web.core.windows.net/
```

---

## 📱 Android/iOS 테스트

```powershell
# 연결된 기기 목록 확인
flutter devices

# 특정 기기로 실행
flutter run -d <device_id>

# 에뮬레이터 목록
flutter emulators

# 에뮬레이터 실행
flutter emulators --launch <emulator_id>
```

---

## 🔍 코드 분석

```powershell
cd can_app

# 오류·경고 확인
flutter analyze

# info 제외 (경고만)
flutter analyze --no-fatal-infos
```

---

## 🏗️ 빌드

```powershell
cd can_app

# Android APK (디버그)
flutter build apk --debug

# Android APK (릴리스)
flutter build apk --release

# Web 빌드
flutter build web
```

---

## 🔥 Firebase 데이터 시드

```powershell
cd firebase
npm install
node seed_all.js
```

### `quotes.json` 전체 대용량 시드 (중복 없이 재실행 가능)

```powershell
cd firebase

# 1) 테스트 삽입 (권장: 먼저 300개)
npm run seed:quotes:test

# 2) 전체 삽입
npm run seed:quotes:full

# 3) 이어서 삽입 (예: 18,000개 이후)
npm run seed:quotes:resume
```

> `seed_all.js`는 명언+저자 해시 기반 문서 ID를 사용하므로 다시 실행해도 중복 문서가 늘지 않습니다.

---

## 🔐 Firebase 인증/룰 배포 (권한 오류 해결)

루트(`vibe_coding_1`) 기준으로 실행합니다.

```powershell
cd C:/dev/vibe_coding_1

# 1) Firebase 로그인
npx --yes firebase-tools login

# 2) 현재 로그인 계정 확인
npx --yes firebase-tools login:list

# 3) 프로젝트 확인 (기본: vibe-coding-1-abec4)
npx --yes firebase-tools use

# 4) Firestore rules 배포
npx --yes firebase-tools deploy --only firestore:rules
```

Firebase Console에서 아래도 반드시 확인:

1. Authentication > Sign-in method > Anonymous 활성화
2. Authentication > Sign-in method > Google 활성화
3. Authentication > Settings > Authorized domains에 `localhost` 포함 (웹 개발 시)
4. Firestore Database가 Native mode로 생성되어 있는지 확인

### OAuth 차단 오류 해결 (This domain is not authorized...)

운영 웹사이트에서 Google 로그인 시 아래 오류가 나오면,
Authentication 허용 도메인에 배포 도메인을 추가해야 합니다.

```text
This domain is not authorized for OAuth operations for your Firebase project.
```

설정 경로:

1. Firebase Console > Authentication > Settings > Authorized domains
2. Add domain 클릭
3. 아래 도메인 추가

```text
canweb125962.z7.web.core.windows.net
localhost
```

반영 후 브라우저 캐시를 비우고 새로고침(또는 시크릿 모드)한 뒤 다시 로그인 시도합니다.

---

## 💡 자주 쓰는 단축키 (실행 중 터미널)

| 키 | 동작 |
|----|------|
| `R` | Hot Restart (전체 재시작) |
| `r` | Hot Reload (빠른 새로고침) |
| `h` | 단축키 전체 목록 |
| `q` | 종료 |
| `d` | Detach (앱 유지하고 detach) |
