# 오픈런 (OpenRun) v3

커뮤니티 핫딜을 한곳에 모아 보여주고, 원하는 조건의 딜이 올라오면 바로 푸시로 알려주는 앱.

## 구조

```
functions/          Firebase Cloud Functions (TypeScript) — 2분마다 수집 → 정규화 → 저장 → 알림
  src/sources/      커뮤니티별 파서 (뽐뿌·해외뽐뿌 RSS, 루리웹 RSS, 클리앙, 아카라이브)
  src/normalize.ts  제목에서 쇼핑몰·가격·통화·배송비·카테고리 추출
  src/group.ts      여러 커뮤니티에 올라온 같은 딜 묶기
  src/match.ts      스마트 키워드 알림 매칭 (최대가격·제외어·쇼핑몰·카테고리·방해금지)
  src/pipeline.ts   Firestore 저장, FCM 발송
lib/                Flutter 앱 (통합 피드 / 알림 조건·기록 / 설정)
firestore.rules     보안 규칙 (deals는 읽기 전용, users/{uid}는 본인만)
```

Firestore 데이터:

| 경로 | 내용 |
| --- | --- |
| `deals/{source_postId}` | 정규화된 딜. `groupKey`가 같으면 같은 딜 |
| `users/{uid}` | `fcmTokens`, `pushEnabled`, `quietStart`/`quietEnd`(KST 시) |
| `users/{uid}/alerts/{id}` | 알림 조건 |
| `users/{uid}/sent/{groupKey}` | 받은 알림 기록 (같은 딜은 한 번만 알림) |

사용자는 익명 로그인(Firebase Auth Anonymous)으로 식별합니다.

## Firebase 연결 (최초 1회) — Android 먼저 출시

1. Firebase 콘솔에서 프로젝트 생성 → **Blaze 요금제**(스케줄 함수에 필요)
2. Authentication → 로그인 방법 → **익명** 사용 설정
3. Firestore Database 생성 (리전: `asia-northeast3` 서울 권장)
4. 앱 연결. 플랫폼 선택에서 **android**만 골라도 됩니다. `google-services.json`과 Gradle 플러그인이 자동으로 추가됩니다. Android 푸시(FCM)는 이것만으로 동작해요.

```bash
dart pub global activate flutterfire_cli
```

```bash
flutterfire configure --platforms=android
```

5. 서버 배포 (Node 22 필요: `brew install node`). Firebase CLI가 오래됐다면(현재 설치본 v11) 먼저 업데이트하세요.

```bash
npm install -g firebase-tools
```

```bash
firebase use --add
```

```bash
cd functions && npm install && cd .. && firebase deploy --only functions,firestore
```

배포 직후 첫 수집은 기존 글을 저장만 하고 알림은 보내지 않습니다. 그다음 수집부터 새 글에 대해 알림이 나갑니다.

6. Play 스토어용 번들 빌드. 서명은 기존 `android/key.properties`와 `android/app/key.jks`를 그대로 씁니다(같은 키여야 기존 앱 업데이트가 됩니다).

```bash
flutter build appbundle --release
```

결과물은 `build/app/outputs/bundle/release/app-release.aab`이고, Play Console 내부 테스트 트랙에 먼저 올리는 걸 권장합니다. Android 13 이상에서는 앱 첫 실행 때 알림 권한을 요청합니다.

### iOS 출시 때 추가로 할 일

1. Apple Developer에서 APNs 인증 키(.p8) 발급 → Firebase 프로젝트 설정 → 클라우드 메시징에 업로드
2. Xcode Runner 타깃 → Signing & Capabilities → **Push Notifications**, **Background Modes › Remote notifications** 추가
3. `flutterfire configure --platforms=android,ios`로 `GoogleService-Info.plist` 추가

## 개발

서버 로직 테스트·실제 사이트 수집 확인은 Deno로 바로 돌릴 수 있습니다(Node 불필요):

```bash
cd functions && deno test -A --sloppy-imports test/
```

```bash
cd functions && deno run -A --sloppy-imports scripts/dump_deals.ts
```

Firebase 없이 앱 UI 확인 (번들된 샘플 데이터 사용, 디버그 빌드 전용):

```bash
cd functions && deno run -A --sloppy-imports scripts/make_fixture.ts
```

```bash
flutter run --dart-define=USE_FIXTURE=true
```

디버그 빌드는 Firebase 설정 파일이 없으면 자동으로 샘플 데이터 모드로 실행됩니다. 릴리스 빌드는 항상 Firebase를 사용합니다.

## 알아둘 점

- 펨코(에펨코리아)는 Cloudflare 보안 챌린지로 서버 수집이 막혀 있어 아카라이브 핫딜로 대체했습니다.
- 뽐뿌는 목록 페이지가 막혀 있어 RSS를 씁니다. RSS에는 썸네일이 없습니다.
- 아카라이브 썸네일 URL은 약 1시간 뒤 만료됩니다. 첫 페이지에 있는 동안은 수집할 때마다 갱신되고, 만료되면 카테고리 아이콘으로 표시됩니다.
- 루리웹 RSS에는 추천·댓글 수가 없어 인기순에서 불리합니다.
