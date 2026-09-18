// 2026-01-19 15:20:00 EST - Lambda Handler 구현
// PRD 001 v1.4.4 섹션 4.2 Lambda 함수 구조

const AWS = require('aws-sdk');
const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const admin = require('firebase-admin');

// Firebase Admin 초기화
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
    })
  });
}

const dynamoDB = new AWS.DynamoDB.DocumentClient();

// ===== 메인 Lambda: 주기적 체크 =====
// CloudWatch Events로 1분마다 자동 실행
exports.checkAllInstances = async (event) => {
  const now = Date.now();
  
  try {
    // 2026-01-22 23:30:00 EST - FCM 토큰 선택적 처리 수정
    // FCM 토큰이 없어도 핑 체크는 계속 진행, 알림만 비활성화
    
    // 1. 앱 설정 조회 (FCM 토큰, 알림 설정)
    const configResult = await dynamoDB.get({
      TableName: process.env.APP_CONFIG_TABLE,
      Key: { config_id: 'default' }
    }).promise();
    
    const config = configResult.Item;
    const fcm_token = config?.fcm_token || null;
    const alert_interval = config?.alert_interval || 600000;
    const enable_alerts = config?.enable_alerts !== false; // 기본값 true
    
    // FCM 토큰 없으면 경고만 출력하고 계속 진행
    if (!fcm_token) {
      console.log('FCM 토큰 미설정 - 알림 비활성화 모드로 작동');
    }
    
    // 2. DynamoDB에서 모든 인스턴스 조회
    const instances = await dynamoDB.scan({
      TableName: process.env.INSTANCES_TABLE
    }).promise();
    
    if (!instances.Items || instances.Items.length === 0) {
      console.log('등록된 인스턴스 없음');
      return { statusCode: 200, body: 'No instances' };
    }
    
    // 3. 병렬 처리 (timeout 방지)
    const checkPromises = instances.Items.map(async (instance) => {
      try {
        const { 
          instance_id, alias, ip_address, health_check_url,
          check_interval, timeout = 10000, failure_count = 0,
          last_checked_at, last_status, last_alert_sent_at = 0,
          recent_checks = []
        } = instance;
        
        // 설정된 주기가 도래했는지 확인 (check_interval은 초 단위)
        const elapsedTime = (now - last_checked_at) / 1000; // 초 단위로 변환
        if (elapsedTime < check_interval) {
          console.log(`Skip ${instance_id}: 아직 주기 미도래`);
          return;
        }
        
        // 핑 체크 실행 (Health Check URL 우선, 없으면 기본 IP)
        const targetUrl = health_check_url || `http://${ip_address}/`;
        const pingResult = await checkInstanceHealth(targetUrl, timeout);
        
        // 상태 판정 로직
        let newStatus = last_status;
        let newFailureCount = failure_count;
        
        if (pingResult.status === 'UP') {
          // 성공 → 실패 카운트 리셋, UP 상태
          newStatus = 'UP';
          newFailureCount = 0;
        } else {
          // 실패 → 카운트 증가
          newFailureCount = failure_count + 1;
          
          // 3회 연속 실패 시 DOWN 판정
          if (newFailureCount >= 3) {
            newStatus = 'DOWN';
            newFailureCount = 3; // 더 이상 증가 안 함
          }
        }
        
        // recent_checks 배열 업데이트 (최근 20개만 유지)
        const newCheck = {
          status: newStatus,
          time: Math.floor(now / 1000), // 초 단위
          rt: pingResult.responseTime
        };
        const updatedRecentChecks = [newCheck, ...recent_checks].slice(0, 20);
        
        // 2026-01-22 23:30:00 EST - FCM 토큰 있을 때만 알림 전송
        // 상태 변화 감지 및 알림 전송
        let newAlertTime = last_alert_sent_at;
        
        if (fcm_token && enable_alerts && newStatus !== last_status) {
          // UP → DOWN 또는 DOWN → UP 전환 시 알림
          await sendPushNotification(fcm_token, {
            title: `[Pinger] ${alias} ${newStatus}!`,
            body: `${ip_address} - ${new Date().toLocaleString('ko-KR', { timeZone: 'America/New_York' })}`,
            status: newStatus,
            instanceId: instance_id,
            responseTime: pingResult.responseTime
          });
          
          newAlertTime = now;
        } 
        // DOWN 상태 지속 중 재알림
        else if (fcm_token && enable_alerts && newStatus === 'DOWN' && 
                 (now - last_alert_sent_at) >= alert_interval) {
          await sendPushNotification(fcm_token, {
            title: `[Pinger] ${alias} 여전히 DOWN`,
            body: `${ip_address} - ${Math.floor((now - last_alert_sent_at) / 60000)}분째 다운`,
            status: 'DOWN',
            instanceId: instance_id,
            responseTime: null
          });
          
          newAlertTime = now;
        }
        
        // DynamoDB 업데이트
        await dynamoDB.update({
          TableName: process.env.INSTANCES_TABLE,
          Key: { instance_id },
          UpdateExpression: `SET 
            last_checked_at = :now, 
            last_status = :status, 
            last_response_time = :rt,
            failure_count = :fc,
            last_alert_sent_at = :alert_time,
            recent_checks = :recent`,
          ExpressionAttributeValues: {
            ':now': now,
            ':status': newStatus,
            ':rt': pingResult.responseTime,
            ':fc': newFailureCount,
            ':alert_time': newAlertTime,
            ':recent': updatedRecentChecks
          }
        }).promise();
        
        console.log(`Checked ${alias}: ${newStatus}`);
      } catch (error) {
        console.error(`Error checking ${instance.alias}:`, error);
      }
    });
    
    // 모든 체크 완료 대기 (최대 50초)
    await Promise.all(checkPromises);
    
    return { statusCode: 200, body: JSON.stringify({ message: 'Check completed' }) };
  } catch (error) {
    console.error('checkAllInstances error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};

// ===== 핑 체크 로직 =====
// 2026-01-22 23:50:00 EST - 상태 판정 기준 수정 (4xx도 UP으로 판정)
async function checkInstanceHealth(url, timeout = 10000) {
  const startTime = Date.now();
  
  try {
    // HTTP Health Check
    const response = await axios.get(url, { 
      timeout,
      validateStatus: () => true // 모든 상태 코드 허용
    });
    
    const responseTime = Date.now() - startTime;
    
    // HTTP 응답을 받았다 = 서버 살아있음
    // 4xx(404, 403 등)도 UP (서버가 응답함)
    // 5xx만 DOWN (서버 오류이지만 일단 응답은 옴, UP으로 분류)
    // 실제 DOWN은 타임아웃/연결 실패만
    const isUp = response.status >= 200 && response.status < 600;
    
    return {
      status: isUp ? 'UP' : 'DOWN',
      responseTime: isUp ? responseTime : null
    };
  } catch (error) {
    // 연결 실패, 타임아웃 등 = DOWN (이것이 진짜 서버 먹통)
    console.error(`Health check failed for ${url}:`, error.message);
    return { status: 'DOWN', responseTime: null };
  }
}

// ===== FCM 푸시 전송 =====
async function sendPushNotification(fcmToken, data) {
  try {
    const message = {
      token: fcmToken,
      notification: {
        title: data.title,
        body: data.body
      },
      data: {
        status: data.status,
        instanceId: data.instanceId,
        responseTime: data.responseTime?.toString() || '0',
        timestamp: new Date().toISOString()
      },
      android: { 
        priority: 'high',
        notification: { 
          sound: 'default',
          channelId: 'pinger_default_channel'  // 2026-01-23 00:55:00 EST - 앱의 채널 ID와 일치시킴
        }
      }
    };
    
    console.log('푸시 전송 시도:', JSON.stringify({ title: data.title, token: fcmToken.substring(0, 20) + '...' }));
    
    const response = await admin.messaging().send(message);
    
    console.log(`✅ 푸시 전송 성공: ${data.title}, MessageID: ${response}`);
  } catch (error) {
    console.error('❌ 푸시 전송 실패:', error);
    console.error('에러 코드:', error.code);
    console.error('에러 메시지:', error.message);
    if (error.errorInfo) {
      console.error('에러 상세:', JSON.stringify(error.errorInfo));
    }
  }
}

// ===== API Lambda: 앱에서 호출 =====
exports.apiHandler = async (event) => {
  const { httpMethod, path, body } = event;
  const data = JSON.parse(body || '{}');
  
  try {
    // 간단한 API Key 검증 (개인용)
    const apiKey = event.headers['x-api-key'] || event.headers['X-Api-Key'];
    if (apiKey !== process.env.API_KEY) {
      return { 
        statusCode: 401, 
        body: JSON.stringify({ error: 'Unauthorized' }),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    // FCM 토큰 및 알림 설정 업데이트
    if (httpMethod === 'PUT' && path === '/config') {
      const configUpdate = {
        config_id: 'default',
        updated_at: Date.now()
      };
      
      if (data.fcm_token) configUpdate.fcm_token = data.fcm_token;
      if (data.alert_interval !== undefined) configUpdate.alert_interval = data.alert_interval;
      if (data.enable_alerts !== undefined) configUpdate.enable_alerts = data.enable_alerts;
      
      await dynamoDB.put({
        TableName: process.env.APP_CONFIG_TABLE,
        Item: configUpdate
      }).promise();
      
      return { 
        statusCode: 200, 
        body: JSON.stringify({ message: 'Config updated' }),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    // 인스턴스 추가
    if (httpMethod === 'POST' && path === '/instances') {
      const instance = {
        instance_id: uuidv4(),
        alias: data.alias,
        ip_address: data.ip_address,
        health_check_url: data.health_check_url || null,
        check_interval: data.check_interval || 300,
        timeout: data.timeout || 10000,
        failure_count: 0,
        recent_checks: [],
        memo: data.memo || '',
        last_checked_at: 0,
        last_status: 'UNKNOWN',
        last_response_time: null,
        last_alert_sent_at: 0,
        created_at: Date.now()
      };
      
      await dynamoDB.put({
        TableName: process.env.INSTANCES_TABLE,
        Item: instance
      }).promise();
      
      return { 
        statusCode: 201, 
        body: JSON.stringify(instance),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    // 인스턴스 목록 조회
    if (httpMethod === 'GET' && path === '/instances') {
      const result = await dynamoDB.scan({
        TableName: process.env.INSTANCES_TABLE
      }).promise();
      
      return {
        statusCode: 200,
        body: JSON.stringify(result.Items || []),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    // 인스턴스 수정
    if (httpMethod === 'PUT' && path.startsWith('/instances/')) {
      const instanceId = path.split('/')[2];
      
      const updateExpr = [];
      const exprAttrValues = {};
      
      if (data.alias) {
        updateExpr.push('alias = :alias');
        exprAttrValues[':alias'] = data.alias;
      }
      if (data.ip_address) {
        updateExpr.push('ip_address = :ip');
        exprAttrValues[':ip'] = data.ip_address;
      }
      if (data.health_check_url !== undefined) {
        updateExpr.push('health_check_url = :hc');
        exprAttrValues[':hc'] = data.health_check_url;
      }
      if (data.check_interval) {
        updateExpr.push('check_interval = :ci');
        exprAttrValues[':ci'] = data.check_interval;
      }
      if (data.timeout) {
        updateExpr.push('timeout = :to');
        exprAttrValues[':to'] = data.timeout;
      }
      if (data.memo !== undefined) {
        updateExpr.push('memo = :memo');
        exprAttrValues[':memo'] = data.memo;
      }
      
      if (updateExpr.length > 0) {
        await dynamoDB.update({
          TableName: process.env.INSTANCES_TABLE,
          Key: { instance_id: instanceId },
          UpdateExpression: 'SET ' + updateExpr.join(', '),
          ExpressionAttributeValues: exprAttrValues
        }).promise();
      }
      
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Instance updated' }),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    // 인스턴스 삭제
    if (httpMethod === 'DELETE' && path.startsWith('/instances/')) {
      const instanceId = path.split('/')[2];
      
      await dynamoDB.delete({
        TableName: process.env.INSTANCES_TABLE,
        Key: { instance_id: instanceId }
      }).promise();
      
      return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Instance deleted' }),
        headers: { 'Content-Type': 'application/json' }
      };
    }
    
    return { 
      statusCode: 404, 
      body: JSON.stringify({ error: 'Not found' }),
      headers: { 'Content-Type': 'application/json' }
    };
  } catch (error) {
    console.error('apiHandler error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: { 'Content-Type': 'application/json' }
    };
  }
};
