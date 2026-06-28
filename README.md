# CAN 🌟

> **"당신은 할 수 있습니다 (You CAN)."**  
> 시대를 초월한 명언과 사용자의 마음을 연결하는 모바일 동기부여 플랫폼

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/KKiyatho/vibe_coding_1)
[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 📱 앱 소개

**CAN**은 모바일에 최적화된 동기부여 플랫폼입니다. 단순히 명언을 보여주는 앱을 넘어, 사용자의 감정과 상황에 맞춘 맞춤 명언 추천, 배경화면 제작, 커뮤니티 공유 등 **일상의 작은 변화를 만드는** 통합 경험을 제공합니다.

### 🎯 핵심 가치
- **감정 기반 추천**: "지치고 힘들어" → 맞춤형 명언 자동 추천
- **한 손 조작**: 모든 주요 기능을 하단 탭과 엄지손가락 범위 내에 배치
- **개인화**: 테마 색상(5가지) + 다크/라이트 모드 + 언어 선택
- **창작의 즐거움**: 명언으로 배경화면 생성 → 기기 저장

---

## ✨ 핵심 기능

### 1️⃣ 홈 — 오늘의 명언
```
매일 한 명언으로 시작하는 긍정의 하루
├─ 새로고침으로 다른 명언 보기
├─ 좋아요 + 북마크 저장
├─ SNS 공유 (카카오톡, 라인 등)
└─ 테마 색상 즉시 변경
```

### 2️⃣ 검색 — 감정 기반 맞춤 추천
```
상황을 입력하면 명언이 답해준다
├─ 감정 입력: "면접 떨려", "관계 힘들어" → 실시간 추천
├─ 빠른 감정 칩: 불안, 지침, 면접, 사랑, 행복, 자기계발
├─ 12개 카테고리 둘러보기
│  └─ 철학자, 기업가, 작가, 과학자, 예술가, 운동선수 등
└─ 무한 스크롤로 더 많은 명언 탐색
```

### 3️⃣ 커뮤니티 — 함께 나누는 응원
```
사용자들의 동기부여 이야기
├─ 게시글 작성: 목표, 깨달음 공유
├─ 하트 토글: 낙관적 업데이트로 즉시 반영
├─ 월간 인기 차트: 가장 많은 하트 받은 글
└─ 긍정의 피드백 문화 형성
```

### 4️⃣ 알람 — 타이핑 미션으로 아침 깨우기
```
명언으로 시작하는 새로운 아침
├─ 휠 형식 UI: 한 손으로 편한 시간 설정
├─ 반복 요일 선택: 월~일 원하는 요일만
├─ 미션형 해제: 지정 문구 타이핑 완료 시 꺼짐
└─ 음성 + 진동 알림
```

### 5️⃣ 배경화면 — 명언을 내 폰에
```
명언이 담긴 고화질 배경화면
├─ 배경 선택
│  ├─ 그라디언트: 12가지 색상 조합
│  ├─ 실사 이미지: 자연, 도시, 하늘 등
│  └─ 단색: 6가지 기본 색
├─ 텍스트 색상 선택
├─ 미리보기 확인
└─ 갤러리에 즉시 저장
```

---

## 🛠️ 기술 스택

| 계층 | 기술 |
|------|------|
| **Frontend** | Flutter 3.8.1 (Dart) |
| **상태 관리** | Riverpod 2.x |
| **백엔드/DB** | Firebase Firestore (36,937개 명언) |
| **인증** | Firebase Auth (Anonymous, Email, Google) |
| **로컬 저장** | SharedPreferences |
| **알람** | flutter_local_notifications + timezone |
| **배경화면** | gal (갤러리 저장) + RepaintBoundary |
| **배포** | Azure Static Web Apps (웹) + Google Play (모바일 예정) |

---

## 📊 프로젝트 규모

- **개발 기간**: 2주 스프린트 (6월 13~28일)
- **코드라인**: ~2,500 LOC (Flutter)
- **Firestore 규칙**: 보안 강화 (읽기 인증 필수, 쓰기 필드 검증)
- **데이터**: 36,937개 명언 (한국어/영어 혼합)

---

## 🎨 UI/UX 특징

### 디자인 철학
- **극도의 단순함**: 사용자가 메시지에 집중하도록 유도
- **모바일 최적화**: Thumb-zone(엄지손가락 범위) 내 모든 조작
- **개인화**: 5가지 테마 색상 + 다크/라이트 모드 즉시 반영

### 화면 구성
```
┌─────────────────────────────┐
│   CAN     [프로필] [테마] [언어] [⚙️]   │
├─────────────────────────────┤
│                             │
│       [콘텐츠 영역]          │
│                             │
├─────────────────────────────┤
│ [홈][검색][커뮤니티][알람][배경화면]  │
└─────────────────────────────┘
```

---

## 💡 주요 구현 사항

### 1. 대용량 데이터 처리
- **36,937개 명언 Firestore 시드**: 무료 플랜(Spark) 한도 내 안전한 배치 삽입
- **커서 기반 페이지네이션**: offset 방식보다 효율적인 `startAfterDocument` 사용
- **로컬 캐싱**: SharedPreferences로 첫 페이지 캐시 → API 호출 최소화

### 2. 감정 기반 추천
- **TagExtractor**: 자연어 문장 → 16개 사전 정의 태그로 매핑
  - 예: "면접이 긴장돼" → ['면접', '용기', '성공']
- **태그 검색**: Firestore 쿼리로 일치하는 명언 반환
- **향후 고도화**: pgvector 기반 벡터 유사도 검색

### 3. 테마 시스템 (전역 상태)
```
ThemeState
├─ colorIndex: 5가지 색상
├─ isDark: 다크/라이트 모드
└─ languageCode: 'ko' / 'en'
```
→ Riverpod으로 앱 전역에 즉시 반영, SharedPreferences 저장

### 4. 보안 강화
- Firestore rules: 읽기 인증 필수, 쓰기 필드 검증
- 이미지 업로드: 파일 시그니처(magic bytes) 검증
- 내부 오류 메시지 노출 제거

---

## 🚀 배포 현황

### 웹
- **운영 URL**: https://canweb125962.z7.web.core.windows.net/
- **배포 방식**: Azure Static Web Apps
- **상태**: ✅ 1.1.0 배포 완료

### 모바일 (예정)
- **Android**: Google Play Store 제출 준비 중
- **iOS**: App Store 제출 준비 중

---

## 📝 사용자 피드백 반영

| 피드백 | 조치 |
|--------|------|
| 검색 결과 없는데도 추천 명언이 나옴 | 빈 결과 화면 표시 로직 개선 |
| 다른 탭 다녀온 후 검색 화면이 남아있음 | 검색 탭 진입 시 초기화 구현 |
| 로그인 없이 명언 보고 싶음 | 익명 로그인(Anonymous Auth) 추가 |
| 기존 명언 앱과의 차별성 불명확 | 감정추천·저장·배경화면·커뮤니티 기능 강조 |

---

## 🎯 향후 계획

### Phase 2 (7월~8월)
- [ ] pgvector 기반 벡터 검색 고도화
- [ ] 커뮤니티 실시간 채팅 기능
- [ ] 팔로우 시스템 및 개인 프로필 페이지
- [ ] 홈 화면 위젯 지원

### Phase 3 (9월~)
- [ ] AI 생성 명언 (프롬프트 기반)
- [ ] 소셜 로그인 확대 (카카오, 네이버)
- [ ] 월간 명언 뉴스레터
- [ ] 웹 버전 고도화 (PWA)

---

## 🔧 로컬 설치 및 실행

### 요구사항
- Flutter 3.8.1+
- Dart 3.8+
- Firebase CLI

### 설치
```bash
cd can_app
flutter pub get
```

### 웹에서 실행
```bash
flutter run -d chrome
```

### 웹 빌드 & 배포
```bash
flutter build web --release
# Azure Storage 업로드
az storage blob upload-batch --account-name canweb125962 --source ./build/web --destination '$web'
```

### Firebase Rules 배포
```bash
firebase deploy --only firestore:rules
```

---

## 📚 프로젝트 문서

| 파일 | 내용 |
|------|------|
| [MVP.md](MVP.md) | 1차 출시 범위 및 핵심 시나리오 |
| [agent.md](agent.md) | AI 어시스턴트 개발 지침 |
| [COMMANDS.md](COMMANDS.md) | 개발·배포 명령어 모음 |
| [활동기록.md](활동기록.md) | 주간 개발 로그 |

---

## 👤 개발자

**최민준** (KKiyatho)  
- GitHub: [@KKiyatho](https://github.com/KKiyatho)
- Email: hellochoi1016@gmail.com

---

## 📄 라이선스

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 🎬 스크린샷

| 홈 (라이트) | 검색 | 커뮤니티 |
|-----------|------|---------|
| ![Home Light](screenshots/home_light.png) | ![Search](screenshots/search.png) | ![Community](screenshots/community.png) |

| 알람 | 배경화면 | 홈 (다크) |
|------|---------|---------|
| ![Alarm](screenshots/alarm.png) | ![Wallpaper](screenshots/wallpaper.png) | ![Home Dark](screenshots/home_dark.png) |

---

## 🙏 인용

- **명언 데이터**: Open source quote databases
- **디자인 영감**: Apple Music, Notion
- **기술 지원**: Flutter, Firebase, Riverpod 커뮤니티

---

**Made by 최민준**
