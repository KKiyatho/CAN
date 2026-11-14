# CAN

> "당신은 할 수 있습니다 (You CAN)."
> 명언과 사용자의 마음을 연결하는 모바일 동기부여 앱

## 기능

| 탭 | 내용 |
|----|------|
| 홈 | 오늘의 명언, 좋아요·저장·공유, 테마 색상·다크 모드·언어(한/영) |
| 검색/추천 | 감정·상황 입력 → AI 추천(실패 시 로컬 검색), 카테고리 둘러보기 |
| 커뮤니티 | 게시글 작성·좋아요·월간 인기 글·신고·삭제 (가입 계정만 작성, 게스트는 읽기·좋아요) |
| 알람 | 반복 요일, 지정 문구를 정확히 입력해야 해제되는 알람 |
| 배경화면 | 명언 배경화면 제작, 갤러리/다운로드 저장 |

계정: 이메일, Google, 게스트(익명). 프로필 화면에서 로그아웃과 계정 삭제를 제공한다.

## 구조

```
can_app/     Flutter 앱 (Riverpod, Supabase Auth)
api/         Azure Functions — POST /api/recommend, GET /api/health
supabase/    DB 마이그레이션 (프로필·커뮤니티, RLS 포함)
```

| 영역 | 기술 |
|------|------|
| 인증·DB | Supabase Auth + PostgreSQL(RLS) |
| 명언 | 앱에 포함된 `quotes_curated.json`(511개, 한/영) |
| 감정 추천 | Azure Functions → Azure OpenAI. Supabase 로그인 토큰 필수 |
| 로컬 저장 | 북마크·좋아요·최근 검색·알람·설정 (로그아웃 시 개인 기록 삭제) |
| 알람 | flutter_local_notifications + 앱 내 해제 화면 |
| 웹 배포 | Azure Storage 정적 웹사이트 — https://canweb125962.z7.web.core.windows.net/ |

## 알아둘 제한

- 웹 알람은 탭이 열려 있는 동안에만 울린다. 모바일은 OS 알림 예약을 사용한다.
- AI 추천 문구는 모델이 생성하며 출처 검증이 보장되지 않는다. 서버가 형식·언어·중복·길이를 검증한다.
- API 요청 제한은 Function 인스턴스별 메모리 기준이다.

## 시작하기

```powershell
cd can_app
flutter pub get
flutter run -d chrome
```

DB 적용, API 설정, 스토어 배포 절차는 [COMMANDS.md](COMMANDS.md)를 따른다.

## 검증

```powershell
cd can_app; flutter analyze; flutter test
cd ..\api; npm test
```

CI(`.github/workflows/ci.yml`)가 같은 검사를 실행한다.

## 문서

| 파일 | 내용 |
|------|------|
| [COMMANDS.md](COMMANDS.md) | 개발·배포·운영 절차 |
| [PRD.md](PRD.md), [MVP.md](MVP.md) | 제품 요구사항과 1차 범위 |
| [기획.md](기획.md) | 초기 기획 |
