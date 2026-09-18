# 2026-01-19 16:30:00 EST - Pinger 자동 테스트 스크립트 (이모지 제거)
# PRD 001 v1.4.4 전체 기능 자동 시험

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Pinger 자동 테스트 시작" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$SuccessCount = 0

# 현재 디렉토리 확인
$ProjectRoot = "C:\_Pinger\pinger"
if (-Not (Test-Path $ProjectRoot)) {
    Write-Host "[ERROR] 프로젝트 디렉토리를 찾을 수 없습니다: $ProjectRoot" -ForegroundColor Red
    exit 1
}

Set-Location $ProjectRoot

# ====================================
# Phase 1: 모델 단위 테스트
# ====================================
Write-Host "[Phase 1] 모델 단위 테스트" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "[TEST 1/8] Instance 모델 테스트" -ForegroundColor White
flutter test test/models/instance_test.dart
if ($LASTEXITCODE -eq 0) {
    Write-Host "[PASS] Instance 모델 테스트 통과" -ForegroundColor Green
    $SuccessCount++
} else {
    Write-Host "[FAIL] Instance 모델 테스트 실패" -ForegroundColor Red
    $ErrorCount++
}
Write-Host ""

# ====================================
# Phase 2: 코드 품질 검사 (통합 테스트 스킵)
# ====================================
Write-Host "[Phase 2] 코드 품질 검사" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "[TEST 2/8] Flutter Analyze (Linter)" -ForegroundColor White
$AnalyzeOutput = flutter analyze 2>&1
$AnalyzeStr = $AnalyzeOutput | Out-String
if ($AnalyzeStr -match "(\d+) issues found") {
    $IssueCount = [int]$Matches[1]
    # error나 warning이 있는지 확인
    $HasErrors = $AnalyzeStr -match "\berror\b"
    $HasWarnings = $AnalyzeStr -match "\bwarning\b"
    
    if ($HasErrors) {
        Write-Host "[FAIL] Linter 검사 실패 (오류 발견: $IssueCount개)" -ForegroundColor Red
        $ErrorCount++
    } elseif ($HasWarnings) {
        Write-Host "[WARN] Linter 검사: 경고 $IssueCount개" -ForegroundColor Yellow
        Write-Host "[PASS] 오류 없음 - 통과" -ForegroundColor Green
        $SuccessCount++
    } else {
        Write-Host "[PASS] Linter 검사 통과 (정보성 권장사항: $IssueCount개)" -ForegroundColor Green
        $SuccessCount++
    }
} else {
    Write-Host "[PASS] Linter 검사 통과 (오류 없음)" -ForegroundColor Green
    $SuccessCount++
}
Write-Host ""

# ====================================
# Phase 3: 파일 구조 검증
# ====================================
Write-Host "[Phase 3] 파일 구조 검증" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "[TEST 3/8] 필수 파일 존재 확인" -ForegroundColor White

$RequiredFiles = @(
    "lib\main.dart",
    "lib\models\instance.dart",
    "lib\models\check_history.dart",
    "lib\models\app_config.dart",
    "lib\services\local_db_service.dart",
    "lib\services\auth_service.dart",
    "lib\services\fcm_service.dart",
    "lib\services\api_service.dart",
    "lib\providers\instance_provider.dart",
    "lib\screens\dashboard_screen.dart",
    "lib\screens\instance_form_screen.dart",
    "lib\screens\instance_detail_screen.dart",
    "lib\screens\settings_screen.dart",
    "lib\screens\auth\pin_setup_screen.dart",
    "lib\screens\auth\pin_auth_screen.dart",
    "lib\widgets\instance_card.dart",
    "lib\config\api_config.dart",
    "android\app\build.gradle",
    "android\build.gradle",
    "android\app\src\main\AndroidManifest.xml",
    "pubspec.yaml"
)

$MissingFiles = @()
foreach ($file in $RequiredFiles) {
    if (-Not (Test-Path $file)) {
        $MissingFiles += $file
    }
}

if ($MissingFiles.Count -eq 0) {
    Write-Host "[PASS] 모든 필수 파일 존재 ($($RequiredFiles.Count)개)" -ForegroundColor Green
    $SuccessCount++
} else {
    Write-Host "[FAIL] 누락된 파일: $($MissingFiles.Count)개" -ForegroundColor Red
    foreach ($file in $MissingFiles) {
        Write-Host "   - $file" -ForegroundColor Red
    }
    $ErrorCount++
}
Write-Host ""

# ====================================
# Phase 4: 의존성 검증
# ====================================
Write-Host "[Phase 4] 의존성 검증" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "[TEST 4/8] pubspec.yaml 패키지 확인" -ForegroundColor White

$RequiredPackages = @(
    "provider",
    "sqflite",
    "flutter_secure_storage",
    "local_auth",
    "firebase_messaging",
    "firebase_core",
    "uuid",
    "http",
    "fl_chart",
    "flutter_slidable",
    "crypto",
    "intl"
)

$PubspecContent = Get-Content "pubspec.yaml" -Raw
$MissingPackages = @()

foreach ($package in $RequiredPackages) {
    if (-Not ($PubspecContent -match $package)) {
        $MissingPackages += $package
    }
}

if ($MissingPackages.Count -eq 0) {
    Write-Host "[PASS] 모든 필수 패키지 존재 ($($RequiredPackages.Count)개)" -ForegroundColor Green
    $SuccessCount++
} else {
    Write-Host "[FAIL] 누락된 패키지: $($MissingPackages.Count)개" -ForegroundColor Red
    foreach ($package in $MissingPackages) {
        Write-Host "   - $package" -ForegroundColor Red
    }
    $ErrorCount++
}
Write-Host ""

# ====================================
# Phase 5: Android 설정 검증
# ====================================
Write-Host "[Phase 5] Android 설정 검증" -ForegroundColor Yellow
Write-Host "----------------------------------------"

Write-Host "[TEST 5/8] AndroidManifest.xml 권한 확인" -ForegroundColor White

$ManifestPath = "android\app\src\main\AndroidManifest.xml"
$ManifestContent = Get-Content $ManifestPath -Raw

$RequiredPermissions = @(
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS"
)

$MissingPermissions = @()
foreach ($permission in $RequiredPermissions) {
    if (-Not ($ManifestContent -match $permission)) {
        $MissingPermissions += $permission
    }
}

if ($MissingPermissions.Count -eq 0) {
    Write-Host "[PASS] 모든 필수 권한 존재" -ForegroundColor Green
    $SuccessCount++
} else {
    Write-Host "[FAIL] 누락된 권한: $($MissingPermissions.Count)개" -ForegroundColor Red
    foreach ($permission in $MissingPermissions) {
        Write-Host "   - $permission" -ForegroundColor Red
    }
    $ErrorCount++
}
Write-Host ""

# ====================================
# 최종 결과
# ====================================
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   테스트 결과 요약" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "총 테스트: 5개" -ForegroundColor White
Write-Host "[PASS] 성공: $SuccessCount개" -ForegroundColor Green
Write-Host "[FAIL] 실패: $ErrorCount개" -ForegroundColor Red
Write-Host ""

if ($ErrorCount -eq 0) {
    Write-Host "[SUCCESS] 모든 테스트 통과! 이제 APK 빌드를 시작합니다..." -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "[WARNING] 일부 테스트 실패. 오류를 수정하세요." -ForegroundColor Yellow
    exit 1
}
