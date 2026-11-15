# Daily Keep

단어, 할 일, 위키, 링크를 빠르게 담고 다시 찾아보는 흑백 SwiftUI 앱입니다. iPhone(iOS 27.1)과 Mac(macOS 27)에서 같은 코드로 돌아갑니다.

## 실행

```bash
make run        # iPhone Duo 시뮬레이터
make mac        # 맥 앱
make test       # 단위 테스트(macOS)
```

처음 실행하면 `Config/Env.xcconfig`가 예시 파일에서 만들어집니다. 소스 파일을 추가·삭제했다면 `make generate`로 프로젝트를 다시 만듭니다. Xcode 27.1, [XcodeGen](https://github.com/yonaskolb/XcodeGen)이 필요합니다.

## 환경변수 — `Config/Env.xcconfig` 한 파일

| 키 | 설명 |
| --- | --- |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID. 비어 있으면 iCloud 없이 로컬 저장으로 동작합니다 |
| `DK_BUNDLE_ID` | 번들 ID |
| `ICLOUD_ENABLED` / `ICLOUD_CONTAINER` | iCloud(CloudKit private DB) 동기화 |
| `AI_DEFAULT_PROVIDER` | `ondevice` 또는 `gemini`. 앱 설정에서 바꾸기 전 기본값 |
| `GEMINI_API_KEY` / `GEMINI_MODEL` | Gemini 키와 모델명 |

이 파일은 git에 올라가지 않습니다(`Env.example.xcconfig`만 커밋). 값은 Info.plist를 거쳐 `Sources/App/AppConfig.swift`에서만 읽습니다. API 키가 앱 번들에 들어가므로 개인용으로만 배포하세요.

### iCloud 켜기

1. `DEVELOPMENT_TEAM`에 Team ID를 넣고 `make generate`
2. Xcode에서 DailyKeep 타깃 → Signing & Capabilities에 iCloud 컨테이너(`ICLOUD_CONTAINER`)가 잡혔는지 확인합니다. 처음 한 번은 Xcode가 컨테이너를 등록합니다.
3. 두 기기에서 같은 Apple 계정으로 로그인하면 자동으로 맞춰집니다. 설정 화면의 "저장 방식"이 `iCloud 동기화 중`이면 켜진 것입니다.

## 구조

- **탐색 컨테이너** `TabView(.sidebarAdaptable)` → 탭마다 `NavigationStack`
- **ArrangementView** (`Sources/Common/Arranged.swift`, 맥은 폴백)
  - 단어: overlay — 목록 위에 빠른 입력 패널. 기기를 펴면 최근 단어 카드까지 펼쳐집니다
  - 할 일: split — 월 달력 + 고른 날의 일정
  - 위키 편집: split(가로만) — 편집기 + 미리보기
- **콘텐츠 컨테이너** `List`, `ScrollView`
- **저장** SwiftData. 모든 종류가 `KeepItem`(타이틀·날짜·카테고리 다대다)을 공유하고, 검색은 `SearchEngine` 하나로 처리합니다.

## 백업

설정 → 내보내기는 폴더 하나를 만듭니다. 가져오기는 같은 id를 더 최근 것으로 맞춥니다.

```
DailyKeep-Backup-2026-11-15/
  index.json                 전체 구조(카테고리, 항목 id·메타·파일 경로)
  words/<제목>-<id8>.md       YAML front matter + 본문
  todos/  wiki/  links/
  wiki/assets/<uuid>.jpg     위키 사진(본문의 ![](assets/…)와 같은 상대 경로)
  links/assets/<uuid>.jpg    링크 섬네일
```

## 참고

- API는 로컬 Xcode 27.1 Beta SDK 기준입니다. 릴리즈 SDK에서 이름이 바뀔 수 있습니다.
- macOS 27.0 SDK에는 `ArrangementView`가 없어 맥은 `HStack`/하단 고정 패널로 대신합니다.
- 기본 `GEMINI_MODEL` 값은 확인하지 못한 모델명입니다. 404가 나면 Env 파일에서 바꾸세요.
