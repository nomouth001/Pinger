// 2026-01-19 16:07:00 EST - API 설정
// PRD 001 v1.4.4 백엔드 연동 설정

class ApiConfig {
  // TODO: 배포 후 실제 API Gateway URL로 변경
  static const String baseUrl = 'https://YOUR_API_GATEWAY_URL/dev';
  
  // TODO: 배포 후 실제 API Key로 변경
  static const String apiKey = 'YOUR_API_KEY_HERE';
  
  // 개발/프로덕션 환경 분리
  static const bool isDevelopment = true;
  
  // 개발 환경에서는 API 호출 비활성화 (로컬만 사용)
  static bool get isApiEnabled => !isDevelopment && 
                                   !baseUrl.contains('YOUR_API') && 
                                   !apiKey.contains('YOUR_API');
}
