const fastify = require('fastify')({ logger: true });
const axios = require('axios');
const apn = require('apn');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

require('dotenv').config();

// 토큰 저장소 (실제 구현에서는 데이터베이스 사용 권장)
const deviceTokens = {};

// APN 제공자 설정
let apnProvider;

// APN 제공자 초기화 함수
function initializeAPNProvider() {
  try {
    // 토큰 기반 인증 방식 사용
    if (process.env.APN_KEY_ID && process.env.APN_TEAM_ID && process.env.APN_BUNDLE_ID) {
      const options = {
        token: {
          key: process.env.APN_KEY_PATH || path.join(__dirname, 'AuthKey.p8'),
          keyId: process.env.APN_KEY_ID,
          teamId: process.env.APN_TEAM_ID,
        },
        production: process.env.NODE_ENV === 'production'
      };
      
      apnProvider = new apn.Provider(options);
      fastify.log.info('APN 제공자가 토큰 기반 인증으로 초기화되었습니다.');
    } 
    // 인증서 기반 인증 방식 사용 (대체 방법)
    else if (fs.existsSync(path.join(__dirname, 'cert.pem')) && fs.existsSync(path.join(__dirname, 'key.pem'))) {
      const options = {
        cert: path.join(__dirname, 'cert.pem'),
        key: path.join(__dirname, 'key.pem'),
        production: process.env.NODE_ENV === 'production'
      };
      
      apnProvider = new apn.Provider(options);
      fastify.log.info('APN 제공자가 인증서 기반 인증으로 초기화되었습니다.');
    } else {
      fastify.log.warn('APN 인증 정보가 없습니다. VoIP 푸시 알림 기능이 비활성화됩니다.');
    }
  } catch (error) {
    fastify.log.error('APN 제공자 초기화 오류:', error);
  }
}

// 서버 시작 시 APN 제공자 초기화
initializeAPNProvider();

// 기본 HTTP 라우터 (테스트용)
fastify.get('/', async (request, reply) => {
  return { message: 'Fastify 서버가 동작 중입니다.' };
});

// OpenAI API 세션 생성 엔드포인트
fastify.post('/api/v1/realtime/sessions', async (request, reply) => {
  // OpenAI API 키 환경 변수에서 가져오기
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    reply.code(500).send({ error: 'OpenAI API 키가 설정되지 않았습니다.' });
    return;
  }

  // OpenAI API 엔드포인트 및 요청 데이터
  const url = 'https://api.openai.com/v1/realtime/sessions';
  const data = {
    model: 'gpt-4o-mini-realtime-preview',
    modalities: ['audio', 'text'],
    instructions: 'You are a friendly assistant.',
  };
  const headers = {
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };

  try {
    // OpenAI API로 POST 요청 보내기
    const response = await axios.post(url, data, { headers });

    // OpenAI API 응답을 클라이언트로 전달
    reply.send(response.data);
  } catch (error) {
    fastify.log.error(error.response ? error.response.data : error.message); // 에러 로깅 개선
    // 에러 응답 처리
    reply.code(error.response ? error.response.status : 500).send({
      error: 'OpenAI API 요청 중 오류가 발생했습니다.',
      details: error.response ? error.response.data : error.message,
    });
  }
});

// 토큰 등록 엔드포인트
fastify.post('/api/v1/register-token', async (request, reply) => {
  const { user_id, device_token, token_type } = request.body;
  
  // 토큰 저장
  if (!deviceTokens[user_id]) {
    deviceTokens[user_id] = {};
  }
  
  deviceTokens[user_id][token_type] = device_token;
  
  fastify.log.info(`토큰 등록: ${user_id}, ${token_type}, ${device_token}`);
  
  return { success: true };
});

// 통화 푸시 알림 전송 엔드포인트
fastify.post('/api/v1/send-call-push', async (request, reply) => {
  const { caller_id, receiver_id, caller_name } = request.body;
  
  // 수신자의 토큰 확인
  if (!deviceTokens[receiver_id] || !deviceTokens[receiver_id].voip) {
    return reply.code(404).send({ error: '수신자의 VoIP 토큰을 찾을 수 없습니다, ' + receiver_id });
  }
  
  const token = deviceTokens[receiver_id].voip;
  const uuid = uuidv4(); // 고유 통화 ID 생성
  
  // VoIP 푸시 알림 전송
  const notification = new apn.Notification();
  notification.topic = `${process.env.APN_BUNDLE_ID}.voip`; // 앱 번들 ID + .voip
  notification.priority = 10;
  notification.pushType = 'voip';
  notification.expiry = Math.floor(Date.now() / 1000) + 3600; // 1시간 후 만료
  notification.payload = {
    aps: {
      'content-available': 1,
      'sound': 'default'
    },
    uuid: uuid,
    caller_id: caller_id,
    caller_name: caller_name,
    handle: caller_name
  };

  setTimeout(async () => {
    try {
      console.log(`VoIP 푸시 전송 시도: ${token}`);
      const result = await apnProvider.send(notification, token);
      console.log('푸시 알림 전송 결과:', result);
      
      if (result.failed.length > 0) {
        return reply.code(500).send({ error: '푸시 알림 전송 실패', details: result.failed[0].response });
      }
      
      return { success: true, uuid: uuid };
    } catch (error) {
      fastify.log.error('푸시 알림 전송 오류:', error);
      return reply.code(500).send({ error: '푸시 알림 전송 오류', details: error.message });
    }
  }, 1000);
  
});

// 테스트용 엔드포인트 - 등록된 토큰 목록 조회
fastify.get('/api/v1/tokens', async (request, reply) => {
  return { tokens: deviceTokens };
});

// 서버 시작 (포트 3000)
fastify.listen({ port: 3000, host: '0.0.0.0' }, (err, address) => {
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
  fastify.log.info(`서버가 ${address} 에서 실행 중입니다.`);
});

// 서버 종료 시 APN 제공자 종료
process.on('SIGINT', () => {
  if (apnProvider) {
    apnProvider.shutdown();
  }
  process.exit(0);
});