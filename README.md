# ThoughtGraph

로컬 우선(local-first) 그래프형 사고 정리 Android 앱.
사용자가 직접 노드와 연결을 만들고, AI는 **기본 OFF**이며 사용자가 설정에서 직접 켜고
버튼을 눌렀을 때만 조용히 보조합니다.

네이티브 **Kotlin + Jetpack Compose** 로 구현되었습니다. (WebView 래핑 아님)

---

## 실행 / 빌드 방법

Android SDK가 설치된 환경(로컬 PC 또는 Android Studio)에서:

```bash
# 1) local.properties 에 SDK 경로 지정 (Android Studio가 자동 생성하기도 함)
echo "sdk.dir=/path/to/Android/sdk" > local.properties

# 2) 디버그 APK 빌드
./gradlew assembleDebug

# 산출물
# app/build/outputs/apk/debug/app-debug.apk

# 3) 단위 테스트
./gradlew testDebugUnitTest
```

- compileSdk 34 / minSdk 24 / targetSdk 34, JDK 17, Gradle 8.7, AGP 8.5.2, Kotlin 1.9.24
- 필요한 SDK 구성요소: `platforms;android-34`, `build-tools;34.0.0`

### GitHub Actions로 빌드된 APK 다운로드

`.github/workflows/build-apk.yml`가 push마다 GitHub 러너(Android SDK 제공)에서
단위 테스트 → 디버그 APK 빌드 → Release 발행을 수행합니다. **최신 디버그 APK는
아래에서 바로 내려받을 수 있습니다:**

- **Release**: https://github.com/miziixx/mindnode/releases/tag/debug-latest
  → `thoughtgraph-debug.apk`
- 또는 각 Actions 실행의 `thoughtgraph-debug-apk` 아티팩트

> ℹ️ 이 세션의 원격 실행 환경 자체는 egress 정책이 Android SDK 배포 호스트
> `dl.google.com`(및 `maven.google.com` 리다이렉트 대상)을 403으로 차단하여 로컬에서
> `assembleDebug`를 실행할 수 없었습니다. 그래서 빌드는 GitHub Actions에서 수행하도록
> 구성했고, 위 워크플로가 **실제로 APK 빌드에 성공**했습니다(단위 테스트 포함 전 단계 통과).

---

## 검증 상태

| 레이어 | 검증 방법 | 결과 |
|---|---|---|
| `data/Models`, `localtools/ThinkingTools`, `exportimport/GraphSerializer` | kotlinc 컴파일 + JUnit 15개 실행 | ✅ 통과 |
| `data/local/GraphDatabase`, `data/repo/GraphRepository` | kotlinc (android.jar) 컴파일 | ✅ 통과 |
| `settings/*`, `ai/AiClient` | kotlinc (android.jar) 컴파일 | ✅ 통과 |
| `ui/**` (Jetpack Compose) | GitHub Actions에서 `assembleDebug` 빌드 | ✅ 통과 |

전체 앱은 GitHub Actions(Android SDK)에서 단위 테스트와 디버그 APK 빌드가 모두
성공했습니다.

---

## 아키텍처

```
com.thoughtgraph.app
├─ MainActivity                     # Compose 진입점, edge-to-edge, adjustResize
├─ data/
│   ├─ Models.kt                    # NodeType(12종), NodeStatus, Importance, Node/Edge/Graph
│   ├─ local/GraphDatabase.kt       # SQLiteOpenHelper (버전관리·마이그레이션·트랜잭션)
│   └─ repo/GraphRepository.kt      # 저장소 파사드 + 최초 1회 샘플 시드
├─ settings/
│   ├─ SettingsStore.kt             # 일반 앱 설정 (키 저장 안 함)
│   └─ SecureCredentialStore.kt     # Android Keystore 기반 EncryptedSharedPreferences
├─ localtools/ThinkingTools.kt      # 질문/원인·결과/단계/할일·구조점검·자동정렬 (오프라인)
├─ exportimport/GraphSerializer.kt  # JSON/Markdown/AI맥락/백업·복구 (순수)
├─ ai/AiClient.kt                   # 선택형·수동 호출 전용 클라이언트
└─ ui/                              # Compose 화면 (그래프/목록/실행계획/설정/도구/다이얼로그)
```

### 데이터 분리
- 그래프 데이터: SQLite (`thoughtgraph.db`)
- 앱 설정: 일반 SharedPreferences
- **API 키: Android Keystore 기반 보안 저장소에만** (`thoughtgraph_secure_prefs`, 백업 제외)

---

## 기능 매핑 (요구사항 → 구현)

**그래프**: 생성/이름변경/삭제, 노드 추가·수정·삭제·복제·드래그, 연결/연결삭제/관계명,
확대·축소·팬·전체맞춤, 선택 강조, undo/redo(스냅샷 50단계), 검색, 자동저장, 최근 목록, 집중 모드.

**노드 종류(12)**: 중심주제·아이디어·질문·목표·문제·원인·결과·단계·할일·결정·자료·보류.
필드: id·graphId·title·description·type·status·importance·dueAt·estimatedMinutes·x·y·createdAt·updatedAt.
연결 필드: id·graphId·sourceNodeId·targetNodeId·relationType·label·createdAt.

**AI 없는 생각 도구**: 질문 붙이기, 원인·결과, 단계로 나누기, 할 일로 바꾸기, 구조 점검
(목표-완료기준/문제-원인·해결/할일-시간·상태/고립 노드/중복 제목), 자동 정렬. 모두 오프라인.

**실행 계획**: 목표·단계·할 일을 상태(생각/할일/진행중/완료)·중요도·마감·예상시간으로 관리.
목록 뷰 + 실행 계획 뷰.

**내보내기/백업**: JSON 내보내기·가져오기(미리보기+중복/교체 선택), Markdown, AI 전달용 맥락
클립보드 복사, 전체 백업/복구. AI 맥락은 API 호출 없이 텍스트 생성·복사만 수행.

**설정**: AI 사용방식(기본 OFF, 수동호출 고정 ON, 선택노드만 전송 ON), API 연결(제공자
Anthropic/OpenAI/Gemini/사용자지정, 키 표시·숨김, 모델 ID 직접 입력, 사용자 엔드포인트,
연결 확인, 전체 삭제), 로컬 저장(자동저장·기록 저장 안 함), 화면(미니맵·고대비).

**선택형 AI**: 빈틈 찾기·반대 관점·문장 구체화·다음 단계. 흐름은
노드 선택 → 버튼 → **전송 미리보기 → 사용자 확인 → 호출 → 반투명 임시(draft) 노드 →
승인 시에만 DB 저장**. 임시 노드는 절대 자동 저장되지 않습니다. AI 오류는 편집 기능에
영향을 주지 않으며, 미설정 상태에서는 오류 대신 설정 안내를 표시합니다.

---

## 보안 요구 준수
- API 키/`Authorization` 헤더를 일반 SharedPreferences·SQLite·파일·로그·crash·analytics에 저장하지 않음
- Android Keystore 기반 EncryptedSharedPreferences 사용, 화면에서는 마스킹
- 앱 백업 규칙에서 보안 저장소 파일 제외 (`res/xml/backup_rules.xml`, `data_extraction_rules.xml`)
- 요청/응답 원문 미저장(기본), 키 삭제 시 보안 저장소에서 즉시 제거

---

## 남은 제한사항
1. 디버그 APK는 GitHub Actions에서 빌드되어 Release로 제공됩니다. 이 세션의 원격 환경
   자체는 `dl.google.com` egress 차단으로 로컬 `assembleDebug`를 실행할 수 없습니다.
2. UI는 CI 빌드로 컴파일까지 검증되었으나 **에뮬레이터/실기기 런타임 테스트는 미수행**입니다.
   실제 상호작용(드래그·제스처 등)은 기기에서 확인이 필요합니다.
3. 가져오기는 파일 피커 대신 **텍스트 붙여넣기** 방식으로 구현(미리보기·중복/교체 선택 포함).
   SAF(문서 피커) 연동은 후속 확장 지점.
4. 다크 모드는 요구사항대로 이번 범위에서 제외.
