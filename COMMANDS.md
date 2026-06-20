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

## 💡 자주 쓰는 단축키 (실행 중 터미널)

| 키 | 동작 |
|----|------|
| `R` | Hot Restart (전체 재시작) |
| `r` | Hot Reload (빠른 새로고침) |
| `h` | 단축키 전체 목록 |
| `q` | 종료 |
| `d` | Detach (앱 유지하고 detach) |
