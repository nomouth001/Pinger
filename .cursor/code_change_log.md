# 코드 변경 이력

## 2026-01-23 00:55:00 EST - FCM 알림 채널 ID 불일치 수정

### 변경 범위
**백엔드 Lambda (`backend/handler.js`)**
- 라인 222: Android 알림 채널 ID 수정
  - 기존: `channelId: 'pinger_alerts'`
  - 변경: `channelId: 'pinger_default_channel'`

### 변경 사유
**문제:**
- Lambda → Firebase: 푸시 전송 성공 ✅
- Firebase → Android: 알림 표시 안 됨 ❌
- **채널 ID 불일치**로 인한 알림 누락

**원인:**
- Lambda가 `pinger_alerts` 채널로 전송
- 앱은 `pinger_default_channel` 채널만 생성
- Android는 존재하지 않는 채널 ID의 알림을 **무시**함

**해결:**
- Lambda의 채널 ID를 앱과 일치시킴
- 동일 채널 ID로 알림 전송 보장

### 테스트 방법
```bash
cd c:\_Pinger\backend
serverless deploy
```

배포 후 10분 대기하여 푸시 알림 수신 확인

---

## 2026-01-23 00:45:00 EST - FCM 백그라운드 알림 설정 추가

### 변경 범위
**안드로이드 매니페스트 (`pinger/android/app/src/main/AndroidManifest.xml`)**
- 라인 5-6: 백그라운드 알림을 위한 권한 추가
  - `WAKE_LOCK`: 기기를 깨워서 알림 표시
  - `VIBRATE`: 진동 알림
- 라인 33-39: FCM 알림 클릭 intent-filter 추가
- 라인 41-47: FCM 기본 알림 채널 및 아이콘 설정

**앱 FCM 서비스 (`pinger/lib/services/fcm_service.dart`)**
- 라인 1-10: `flutter_local_notifications` import 추가
- 라인 13-15: `FlutterLocalNotificationsPlugin` 인스턴스 추가
- 라인 22-24: 초기화 시 로컬 알림 설정 호출
- 라인 60-90: `_initializeLocalNotifications()` 메서드 추가
  - 로컬 알림 플러그인 초기화
  - 안드로이드 알림 채널 생성 (`pinger_default_channel`)

**패키지 의존성 (`pinger/pubspec.yaml`)**
- 라인 50: `flutter_local_notifications: ^17.0.0` 추가

### 변경 사유
**문제:**
- Lambda → Firebase: 푸시 전송 성공 ✅
- Firebase → 폰: 알림 도착 안 함 ❌
- 백그라운드/종료 상태에서 알림이 표시되지 않음

**원인:**
- 안드로이드는 백그라운드 알림을 위해 **알림 채널**이 필요
- `AndroidManifest.xml`에 FCM 기본 채널 설정 누락
- Foreground만 처리하고 Background 알림 표시 로직 없음

**해결:**
1. 안드로이드 알림 채널 생성 (`pinger_default_channel`)
2. FCM 기본 채널 ID를 매니페스트에 등록
3. 백그라운드 알림 권한 추가 (WAKE_LOCK, VIBRATE)

### 알림 동작 방식
```
Lambda → Firebase → FCM → Android System
                              ↓
                    알림 채널 확인 (pinger_default_channel)
                              ↓
                    백그라운드/잠금화면에 알림 표시
```

---

## 2026-01-23 00:00:00 EST - DynamoDB 동기화 및 중복 방지 추가

### 변경 범위
**앱 상태 관리 (`pinger/lib/providers/instance_provider.dart`)**
- 라인 29-56: `loadInstances()` 메서드 수정
  - 기존: 로컬 DB에서만 읽음
  - 변경: 클라우드(DynamoDB)에서 먼저 가져온 후 로컬 DB와 병합
  - 앱 시작 시 자동으로 DynamoDB와 동기화

- 라인 47-91: `addInstance()` 메서드 수정
  - IP 주소 중복 체크 추가
  - 같은 IP가 이미 있으면 새로 추가하지 않고 업데이트

**앱 로컬 DB 서비스 (`pinger/lib/services/local_db_service.dart`)**
- 라인 121-135: `getInstanceByIpAddress()` 메서드 추가
  - IP 주소로 인스턴스 조회 기능

**앱 API 서비스 (`pinger/lib/services/api_service.dart`)**
- 라인 148-161: `getInstanceByIpAddress()` 메서드 추가
  - 클라우드에서 IP 주소로 인스턴스 조회

### 변경 사유
**문제:**
1. 앱 재설치 시 로컬 DB가 비어있어 아무것도 안 보임
2. DynamoDB에는 데이터가 있지만 앱이 가져오지 않음
3. 같은 IP를 여러 번 등록하면 중복으로 체크됨

**해결:**
1. 앱 시작 시 DynamoDB에서 자동 동기화
2. IP 주소 중복 시 기존 인스턴스 업데이트
3. 로컬과 클라우드 데이터 일치 보장

### 동작 방식
```
앱 시작 → loadInstances()
  ↓
1. DynamoDB에서 인스턴스 목록 가져오기
2. 로컬 DB와 병합 (클라우드 우선)
3. 화면에 표시

인스턴스 추가 → addInstance()
  ↓
1. IP 주소 중복 체크 (클라우드)
2. 중복이면 업데이트, 아니면 새로 추가
3. 로컬 + 클라우드 저장
```

---

## 2026-01-22 23:50:00 EST - 상태 판정 기준 수정 (4xx도 UP으로 판정)

(이전 변경 이력 유지됨)


### 변경 범위
**백엔드 Lambda (`backend/handler.js`)**
- 라인 166-191: `checkInstanceHealth()` 함수 상태 판정 로직 수정
  - 기존: `response.status >= 200 && response.status < 400` (2xx-3xx만 UP)
  - 변경: `response.status >= 200 && response.status < 600` (HTTP 응답 받으면 UP)

### 변경 사유
**문제:**
- 앱의 연결 테스트: 404 응답을 "성공"으로 표시
- Lambda의 핑 체크: 404를 "DOWN"으로 판정
- 불일치로 인해 혼란 발생

**마스터의 요구사항:**
- 감지 목표: AWS 콘솔은 Running이지만 실제로 먹통인 상태
- 이런 경우 HTTP 타임아웃 발생 (응답 없음)
- 404 응답 = 서버 살아있음 = SSH 연결 가능 = reboot 불필요

**해결:**
- HTTP 응답을 받았다 = 서버 작동 중 = UP
- 타임아웃/연결 실패만 = 서버 먹통 = DOWN = 알림 필요

### 판정 기준 변경
```javascript
// 기존 (잘못됨)
const isUp = response.status >= 200 && response.status < 400;
// 404, 500 → DOWN

// 변경 (올바름)
const isUp = response.status >= 200 && response.status < 600;
// 200, 404, 500 등 → UP (HTTP 응답함)
// 타임아웃, 연결 오류 → DOWN (진짜 서버 먹통)
```

---

## 2026-01-22 23:30:00 EST - FCM 토큰 선택적 처리 및 클라우드 동기화 구현

(이전 변경 이력 유지됨)


### 변경 범위
**백엔드 Lambda (`backend/handler.js`)**
- 라인 27-40: FCM 토큰 체크 로직 수정
  - 기존: 토큰 없으면 함수 조기 종료
  - 변경: 토큰 없어도 계속 진행, 경고 로그만 출력
- 라인 100-127: 알림 전송 로직 수정
  - `fcm_token` 존재 여부 확인 후 전송
  - 토큰 없으면 알림 전송 스킵

**앱 FCM 서비스 (`pinger/lib/services/fcm_service.dart`)**
- 라인 1-9: import 추가 (http, dart:convert)
- 라인 80-100: `sendTokenToBackend()` 메서드 구현
  - TODO 제거, 실제 HTTP PUT 요청 구현
  - `/config` 엔드포인트로 FCM 토큰 전송

**앱 메인 (`pinger/lib/main.dart`)**
- 라인 96-117: `_initialize()` 메서드 수정
  - FCM 초기화 후 토큰 자동 백엔드 전송 추가
- 라인 46-57: `build()` 메서드 수정
  - InstanceProvider에 ApiService 주입 로직 추가

**앱 상태 관리 (`pinger/lib/providers/instance_provider.dart`)**
- 라인 1-9: import 추가 (api_service.dart)
- 라인 10-20: ApiService 멤버 변수 및 주입 메서드 추가
- 라인 40-61: `addInstance()` 클라우드 동기화 추가
  - 클라우드 → 로컬 순서로 저장
  - 클라우드 실패 시 로컬만 저장
- 라인 64-79: `updateInstance()` 클라우드 동기화 추가
- 라인 82-97: `deleteInstance()` 클라우드 동기화 추가

### 변경 사유
**문제:**
1. Lambda 함수가 FCM 토큰 없으면 조기 종료하여 핑 체크 미실행
2. 앱이 FCM 토큰 생성만 하고 백엔드로 전송하지 않음 (TODO만 있음)
3. 앱이 인스턴스를 로컬 SQLite에만 저장, DynamoDB로 전송하지 않음

**해결:**
1. Lambda: 토큰 선택적 처리, 핑 체크는 항상 실행
2. 앱: FCM 토큰 자동 백엔드 전송 구현
3. 앱: 인스턴스 CRUD 시 클라우드 동기화

### 기존 코드 (주석 처리)
```javascript
// backend/handler.js 라인 35-38 (삭제됨)
/*
if (!config?.fcm_token) {
  console.log('FCM 토큰이 설정되지 않음');
  return { statusCode: 200, body: 'No FCM token' };
}
*/
```

```dart
// fcm_service.dart 라인 86 (삭제됨)
/*
// TODO: HTTP 요청 구현 (api_service.dart에서 처리)
debugPrint('🚀 FCM 토큰을 백엔드로 전송: $apiUrl');
*/
```

---

## 이전 변경 이력

(기존 이력은 유지됨)
