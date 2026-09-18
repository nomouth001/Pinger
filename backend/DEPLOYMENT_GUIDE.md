# Pinger Backend 배포 가이드
## 2026-01-19 15:45:00 EST

PRD 001 v1.4.4 기준 Lambda + DynamoDB + FCM 배포

---

## 1. 사전 준비

### 1.1 AWS 계정 및 CLI 설치
```bash
# AWS CLI 설치 확인
aws --version

# AWS 계정 설정
aws configure
# AWS Access Key ID: (입력)
# AWS Secret Access Key: (입력)
# Default region: ap-northeast-2
# Default output format: json
```

### 1.2 Serverless Framework 설치
```bash
cd backend
npm install -g serverless
npm install
```

### 1.3 Firebase 설정
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 생성: "Pinger"
3. Android 앱 추가:
   - 패키지 이름: `com.pinger.pinger`
   - google-services.json 다운로드 → `pinger/android/app/` 폴더에 저장
4. 프로젝트 설정 → 서비스 계정 → 비공개 키 생성
   - JSON 파일 다운로드 (Lambda용)

---

## 2. 환경변수 설정

### 2.1 .env 파일 생성
```bash
cd backend
cp env.template .env
```

### 2.2 .env 파일 편집
```bash
# API Key 생성 (PowerShell)
$apiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
echo $apiKey

# .env 파일에 입력
API_KEY=<생성된-API-Key>
FIREBASE_PROJECT_ID=<Firebase-Console의-프로젝트-ID>
FIREBASE_CLIENT_EMAIL=<서비스계정-JSON의-client_email>
FIREBASE_PRIVATE_KEY="<서비스계정-JSON의-private_key-전체>"
```

⚠️ **주의**: FIREBASE_PRIVATE_KEY는 `\n`이 포함된 전체 키를 **큰따옴표**로 감싸야 합니다.

---

## 3. Lambda 배포

### 3.1 개발 환경 배포
```bash
cd backend
serverless deploy --stage dev
```

### 3.2 배포 결과 확인
```
✅ Service deployed to stack pinger-backend-dev
✅ endpoints:
  PUT - https://abc123xyz.execute-api.ap-northeast-2.amazonaws.com/dev/config
  POST - https://abc123xyz.execute-api.ap-northeast-2.amazonaws.com/dev/instances
  GET - https://abc123xyz.execute-api.ap-northeast-2.amazonaws.com/dev/instances
  PUT - https://abc123xyz.execute-api.ap-northeast-2.amazonaws.com/dev/instances/{id}
  DELETE - https://abc123xyz.execute-api.ap-northeast-2.amazonaws.com/dev/instances/{id}
✅ functions:
  checkAllInstances: pinger-backend-dev-checkAllInstances (1분마다 자동 실행)
  api: pinger-backend-dev-api
```

### 3.3 API URL 저장
배포 완료 후 출력된 **API Gateway URL**을 복사하여 Flutter 앱 설정에 사용합니다.

---

## 4. Flutter 앱 설정

### 4.1 로컬 API 설정 파일 생성
`pinger/config.example.json`을 `pinger/config.local.json`으로 복사하고
`API_BASE_URL`, `API_KEY`를 입력합니다. 실제 키를 Dart 소스에 적지 마세요.

```powershell
cd pinger
flutter run --dart-define-from-file=config.local.json
# APK 빌드 시에도 동일한 옵션 사용
flutter build apk --dart-define-from-file=config.local.json
```

`config.local.json`은 Git에서 제외됩니다. 설정하지 않으면 백엔드 요청을 보내지 않습니다.
이 방식은 저장소 노출을 방지하지만 빌드된 앱에 포함된 키를 숨기지는 못합니다.
공개 배포 시에는 사용자별 인증 등 별도 서버 인증 설계가 필요합니다.

### 4.2 Firebase 설정 확인
- `pinger/android/app/google-services.json` 존재 확인
- AndroidManifest.xml 권한 확인 (완료)
- build.gradle 설정 확인 (완료)

---

## 5. 테스트

### 5.1 Lambda 함수 수동 테스트
```bash
# API 테스트 (FCM 토큰 업데이트)
curl -X PUT https://YOUR_API_URL/dev/config \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"fcm_token": "test-token-123"}'

# 인스턴스 추가 테스트
curl -X POST https://YOUR_API_URL/dev/instances \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "alias": "Test Server",
    "ip_address": "8.8.8.8",
    "check_interval": 300,
    "timeout": 10000
  }'
```

### 5.2 CloudWatch 로그 확인
```bash
serverless logs -f checkAllInstances --stage dev --tail
```

### 5.3 Flutter 앱 실행
```bash
cd pinger
flutter run
```

---

## 6. 프로덕션 배포

### 6.1 프로덕션 환경변수 설정
별도의 `.env.prod` 파일 생성 또는 AWS Systems Manager Parameter Store 사용 권장

### 6.2 프로덕션 배포
```bash
serverless deploy --stage prod
```

---

## 7. 모니터링

### 7.1 AWS CloudWatch
- Lambda 실행 로그: `/aws/lambda/pinger-backend-dev-checkAllInstances`
- API Gateway 로그: API Gateway 콘솔에서 확인

### 7.2 DynamoDB 확인
- AWS Console → DynamoDB → Tables
- `pinger-backend-instances-dev`
- `pinger-backend-config-dev`

---

## 8. 비용 예상

### 8.1 무료 티어 (개인용 충분)
- Lambda: 월 100만 요청 무료
  - 1분마다 실행: 43,200 요청/월
  - API 호출: ~1,000 요청/월
  - **총: 44,200 요청/월 (무료 범위 내)**

- DynamoDB: 월 25GB 저장 + 25 읽기/쓰기 용량 무료
  - 예상 사용량: <1MB, <100 요청/월
  - **무료 범위 내**

- CloudWatch: 5GB 로그 무료
  - **무료 범위 내**

**💰 예상 비용: $0/월** (무료 티어 내)

---

## 9. 문제 해결

### 9.1 배포 실패
```bash
# 권한 확인
aws sts get-caller-identity

# 스택 삭제 후 재배포
serverless remove --stage dev
serverless deploy --stage dev
```

### 9.2 Lambda 실행 오류
- CloudWatch Logs 확인
- 환경변수 오타 확인
- Firebase 키 형식 확인 (`\n` 포함 여부)

### 9.3 FCM 푸시 안 옴
- Firebase Console → Cloud Messaging → 활성화 확인
- 앱에서 FCM 토큰 정상 생성 확인
- DynamoDB `app_config_table`에 `fcm_token` 저장 확인

---

## 10. 다음 단계

✅ Phase 2 완료!

**Phase 3 진행:**
- 히스토리 차트 구현
- 상세 화면
- 설정 화면
- 최적화

---

**배포 성공 시 다음 명령 실행:**
```bash
echo "✅ Phase 2 완료: Lambda + FCM 배포 성공!"
```
