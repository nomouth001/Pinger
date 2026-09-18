# Pinger - AWS Lightsail Instance Monitor

[![Flutter](https://img.shields.io/badge/Flutter-3.5.4-blue.svg)](https://flutter.dev/)
[![AWS Lambda](https://img.shields.io/badge/AWS-Lambda-orange.svg)](https://aws.amazon.com/lambda/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Pinger**는 AWS Lightsail 인스턴스의 상태를 실시간으로 모니터링하고, 다운 시 즉시 모바일 푸시 알림을 전송하는 개인용 모니터링 앱입니다.

---

## 🎯 주요 기능

### 📱 모바일 앱 (Flutter - Android)
- **PIN/생체인증**: SHA-256 해싱, 5회 실패 시 1분 잠금
- **인스턴스 관리**: 
  - IP 주소 또는 Health Check URL 등록
  - 체크 주기 설정 (1/3/5/10분)
  - 타임아웃 설정 (1-30초)
- **실시간 상태 모니터링**: UP/DOWN 상태 대시보드
- **히스토리 & 차트**: 
  - 최근 24시간 응답 시간 차트 (fl_chart)
  - 전체 체크 히스토리 (SQLite 로컬 저장)
- **푸시 알림**: Firebase Cloud Messaging
- **설정**: 
  - 알림 활성화/비활성화
  - 재알림 간격 (5분/10분/30분/1시간)
  - PIN 변경
  - 히스토리 삭제

### ☁️ 백엔드 (AWS Lambda + DynamoDB)
- **자동 핑 체크**: 1분마다 CloudWatch Events로 자동 실행
- **병렬 처리**: Promise.all로 여러 인스턴스 동시 체크
- **3회 연속 실패 로직**: 오탐 방지
- **재알림 방지**: 설정한 간격 이후에만 재알림
- **Health Check URL 지원**: HTTP GET 요청
- **DynamoDB**: 인스턴스 정보 + 설정 저장
- **REST API**: 인스턴스 CRUD + 설정 업데이트

---

## 🏗️ 아키텍처

```
┌─────────────────────┐
│  Flutter App        │
│  (Android)          │
│  ├─ PIN Auth        │
│  ├─ Dashboard       │
│  ├─ Charts          │
│  └─ SQLite          │
└──────────┬──────────┘
           │
           │ HTTP API
           │
┌──────────▼──────────┐       ┌──────────────────┐
│  AWS API Gateway    │       │  CloudWatch      │
│                     │       │  Events          │
│  PUT  /config       │       │  (1분 주기)       │
│  POST /instances    │       └────────┬─────────┘
│  GET  /instances    │                │
│  PUT  /instances/id │                │
│  DELETE /instances  │                │
└──────────┬──────────┘                │
           │                           │
           │                           │
      ┌────▼───────────────────────────▼────┐
      │   AWS Lambda (handler.js)           │
      │   ├─ checkAllInstances (1분마다)     │
      │   │   ├─ 병렬 핑 체크                │
      │   │   ├─ 3회 연속 실패 판정          │
      │   │   └─ FCM 푸시 전송              │
      │   └─ apiHandler (앱 요청 처리)       │
      └────────┬──────────────┬──────────────┘
               │              │
    ┌──────────▼────────┐  ┌─▼──────────────┐
    │  DynamoDB         │  │  Firebase       │
    │  ├─ instances     │  │  Cloud          │
    │  └─ app_config    │  │  Messaging      │
    └───────────────────┘  └─────────────────┘
```

---

## 🚀 빠른 시작

### 사전 요구사항
- Flutter SDK 3.5.4+
- Node.js 18+
- AWS CLI 설정 완료
- Firebase 프로젝트

### 1. Backend 배포

```powershell
# 환경변수 설정
cd backend
cp env.template .env
# .env 파일 편집 (API_KEY, FIREBASE_PROJECT_ID 등)

# 패키지 설치
npm install

# AWS 배포
serverless deploy --stage dev

# 배포 완료 후 API Gateway URL 복사
```

### 2. Flutter 앱 설정

```powershell
# Firebase 설정
# 1. Firebase Console에서 google-services.json 다운로드
# 2. pinger/android/app/google-services.json에 저장

# API 설정
# 아래 config.local.json에 API_BASE_URL, API_KEY 입력 (Git 제외)

# 패키지 설치
cd pinger
Copy-Item config.example.json config.local.json
flutter pub get

# 실행
flutter run --dart-define-from-file=config.local.json
```

### 3. 자동 테스트 실행

```powershell
cd C:\_Pinger
pwsh -ExecutionPolicy Bypass -File test_automation.ps1
```

---

## 📦 프로젝트 구조

```
C:\_Pinger/
├── backend/                   # AWS Lambda 백엔드
│   ├── handler.js            # Lambda 함수 (핑 체크 + API)
│   ├── serverless.yml        # AWS 배포 설정
│   ├── package.json          # 의존성
│   ├── env.template          # 환경변수 템플릿
│   └── DEPLOYMENT_GUIDE.md   # 배포 가이드
│
├── pinger/                    # Flutter 앱
│   ├── lib/
│   │   ├── main.dart         # 앱 진입점
│   │   ├── models/           # 데이터 모델
│   │   │   ├── instance.dart
│   │   │   ├── check_history.dart
│   │   │   └── app_config.dart
│   │   ├── services/         # 서비스 레이어
│   │   │   ├── local_db_service.dart    # SQLite
│   │   │   ├── auth_service.dart         # PIN/생체인증
│   │   │   ├── fcm_service.dart          # FCM
│   │   │   └── api_service.dart          # HTTP API
│   │   ├── providers/        # 상태 관리
│   │   │   └── instance_provider.dart
│   │   ├── screens/          # UI 화면
│   │   │   ├── auth/
│   │   │   │   ├── pin_setup_screen.dart
│   │   │   │   └── pin_auth_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── instance_form_screen.dart
│   │   │   ├── instance_detail_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── widgets/          # 재사용 위젯
│   │   │   └── instance_card.dart
│   │   └── config/           # 설정
│   │       └── api_config.dart
│   ├── test/                 # 테스트
│   │   ├── models/
│   │   └── integration/
│   └── android/              # Android 설정
│
├── z_DevDocu_Backup/         # 설계 문서
│   ├── 001_PRD_Pinger_Mobile_v1.md
│   ├── 002_Architecture_and_Flows_v1.md
│   ├── 003_API_Specification_v1.md
│   └── 004_Development_Roadmap_v1.md
│
└── test_automation.ps1       # 자동 테스트 스크립트
```

---

## 🧪 테스트

### 자동 테스트 스크립트 (test_automation.ps1)

8단계 자동 검증:
1. ✅ Instance 모델 단위 테스트
2. ✅ PIN 설정 플로우 통합 테스트
3. ✅ 인스턴스 폼 통합 테스트
4. ✅ Flutter Analyze (Linter)
5. ✅ Debug APK 빌드
6. ✅ 필수 파일 구조 검증
7. ✅ 의존성 검증 (pubspec.yaml)
8. ✅ Android 권한 검증 (AndroidManifest.xml)

### 수동 테스트

```powershell
# 단위 테스트
flutter test test/models/instance_test.dart

# 통합 테스트
flutter test test/integration/

# Linter
flutter analyze

# APK 빌드
flutter build apk --release
```

---

## 💰 비용 예상

### 무료 티어 (개인용 충분)
- **Lambda**: 월 100만 요청 무료
  - 실제 사용: ~44,200 요청/월 (1분 주기)
  - ✅ 무료 범위 내
- **DynamoDB**: 월 25GB + 25 읽기/쓰기 무료
  - 실제 사용: <1MB, <100 요청/월
  - ✅ 무료 범위 내
- **CloudWatch**: 5GB 로그 무료
  - ✅ 무료 범위 내
- **Firebase FCM**: 무제한 무료

**💵 총 비용: $0/월** (무료 티어 내)

---

## 🔐 보안

- **PIN 인증**: SHA-256 해싱 (salt 없음, 개인용)
- **생체인증**: Android Biometric API
- **5회 실패 잠금**: 1분 lockout
- **API Key 인증**: x-api-key 헤더 (고정)
- **Firebase Admin SDK**: Private key 환경변수 저장

---

## 📖 문서

- [PRD (Product Requirements Document)](z_DevDocu_Backup/001_PRD_Pinger_Mobile_v1.md)
- [Architecture & Data Flows](z_DevDocu_Backup/002_Architecture_and_Flows_v1.md)
- [API Specification](z_DevDocu_Backup/003_API_Specification_v1.md)
- [Development Roadmap](z_DevDocu_Backup/004_Development_Roadmap_v1.md)
- [Backend Deployment Guide](backend/DEPLOYMENT_GUIDE.md)
- [Firebase Setup](pinger/FIREBASE_SETUP.txt)

---

## 🛠️ 기술 스택

### Frontend
- **Framework**: Flutter 3.5.4
- **State Management**: Provider 6.1.0
- **Local DB**: sqflite 2.3.0
- **Authentication**: local_auth 2.1.0, flutter_secure_storage 9.0.0, crypto 3.0.3
- **Push Notifications**: firebase_messaging 14.7.0
- **Charts**: fl_chart 0.65.0
- **HTTP**: http 1.1.0
- **UI**: flutter_slidable 3.0.0

### Backend
- **Runtime**: AWS Lambda (Node.js 18)
- **Framework**: Serverless Framework 3.38.0
- **Database**: AWS DynamoDB
- **Push**: Firebase Admin SDK 12.0.0
- **HTTP Client**: axios 1.6.0
- **Scheduler**: AWS CloudWatch Events

---

## 📝 변경 로그

전체 변경 로그는 [.cursor/code_change_log.md](.cursor/code_change_log.md)를 참조하세요.

---

## 📄 라이선스

MIT License - 개인 사용 목적

---

## 🙏 감사의 말

이 프로젝트는 AWS Lightsail 인스턴스의 안정적인 모니터링을 위해 개발되었습니다.

**Made with ❤️ by LTH**

---

## 📞 문의

문제가 발생하면 Issues를 통해 제보해주세요.

---

**🎉 Phase 1-4 완료! 모든 기능이 구현되었습니다!**
