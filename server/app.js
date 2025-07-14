const fastify = require('fastify')({ logger: true });
const axios = require('axios');
const apn = require('apn');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');

require('dotenv').config();

// 토큰 저장소 (실제 구현에서는 데이터베이스 사용 권장)
const deviceTokens = {};

// APN 제공자 설정
let apnProvider;

// Supabase 클라이언트 초기화
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY; // service_role key 권장

const supabase = createClient(supabaseUrl, supabaseKey);

// key: userId_originalDay_originalTime (e.g., user123_수_17:05), value: YYYY-MM-DD of last send
const recentNotifications = new Map(); 
let upcomingNotificationsToSend = []; // 5분 스케줄러가 다음 5분간 보낼 알림들을 임시 저장

// Rate limiting을 위한 임시 저장소 (실제 환경에서는 Redis 사용 권장)
const purchaseAttempts = new Map();

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
      // fastify.log.info('APN 제공자가 토큰 기반 인증으로 초기화되었습니다.');
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

  // 기본 프롬프트 가져오기
  const basePrompt = fs.readFileSync(path.join(__dirname, 'prompt.txt'), 'utf8');
  
  // 클라이언트에서 보낸 사용자 정보 추출
  const { user_name, self_intro, voice, history, language = 'ko' } = request.body || {};
  
  // // 사용자별 맞춤형 프롬프트 작성
  // if (user_name) {
    // }
  let customPrompt = `
  대화상대의 이름은 ${user_name}입니다. 
  [instructions], [history]을 참고하여 대화를 진행해주세요. 
  [instructions]에서 따로 명시되지 않은 경우, 대화는 한국어로 진행해주세요. 
  `;
  
  customPrompt += basePrompt;

  // 사용자 정보 섹션 추가
  let userInfo = "";
  userInfo += "\n[instructions]";
  if (self_intro && self_intro.trim() !== "") {
    userInfo += `\n"${self_intro}"`;
  } else {
    userInfo += basePrompt;
  }
  userInfo += "\n";

  let historyString = ""; // 새로운 변수 선언
  if (history) {
      // Supabase에서 가져온 history 배열을 문자열로 변환
      const historyText = history.map(record => 
          `- ${record.created_at}: ${record.transcript || '내용 없음'}`
      ).join("\n");
      historyString = `\n\n[history]\n${historyText}`;
  }
  
  // 최종 프롬프트 생성
  const finalPrompt = customPrompt + userInfo + historyString;
  
  // OpenAI API 엔드포인트 및 요청 데이터
  const url = 'https://api.openai.com/v1/realtime/sessions';
  const data = {
      // model: 'gpt-4o-realtime-preview-2025-06-03',
      model: 'gpt-4o-mini-realtime-preview',
      modalities: ['audio', 'text'],
      instructions: finalPrompt,
      // 'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', and 'verse'
      voice: voice,
      temperature: 0.7,
      input_audio_transcription: {
          language: language,
          model: 'whisper-1'
      }
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

  if (!user_id || !device_token || !token_type) {
    return reply.code(400).send({ error: 'user_id, device_token, token_type은 필수입니다.' });
  }

  let columnToUpdate = {};
  if (token_type === 'voip') {
    columnToUpdate.voip_token = device_token;
  } else {
    return reply.code(400).send({ error: '지원되지 않는 token_type입니다.' });
  }

  try {
    const { data, error } = await supabase
      .from('users')
      .update(columnToUpdate)
      .eq('auth_id', user_id) // users 테이블의 사용자 식별 컬럼명에 맞춰주세요.
      .select(); // 업데이트된 레코드를 반환받아 확인할 수 있습니다.

    if (error) {
      fastify.log.error(`토큰 업데이트 오류 (user: ${user_id}, type: ${token_type}):`, error);
      return reply.code(500).send({ error: '데이터베이스 오류로 토큰 업데이트에 실패했습니다.', details: error.message });
    }

    if (!data || data.length === 0) {
        fastify.log.warn(`토큰 업데이트 시도: 사용자를 찾을 수 없음 (user_id: ${user_id})`);
        return reply.code(404).send({ error: '토큰을 등록할 사용자를 찾을 수 없습니다.' });
    }

    // fastify.log.info(`Supabase users 테이블 토큰 등록/업데이트: user_id=${user_id}, type=${token_type}, token=${device_token}`);
    return { success: true, message: '토큰이 성공적으로 데이터베이스에 등록/업데이트되었습니다.' };

  } catch (err) {
    fastify.log.error(`토큰 등록 중 예외 발생 (user: ${user_id}, type: ${token_type}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 토큰 등록에 실패했습니다.' });
  }
});

// APN Provider 초기화 아래, 또는 공통 유틸리티 함수 영역에 배치 가능

async function sendVoipPushNotification(fastifyInstance, receiverVoipToken, payload, notificationKeyForLog) {
  if (!apnProvider) {
    fastifyInstance.log.error(`[VoIP Push Send] APN Provider가 초기화되지 않아 ${notificationKeyForLog} 푸시를 보낼 수 없습니다.`);
    return { success: false, error: 'APN Provider not initialized' };
  }
  if (!receiverVoipToken) {
    fastifyInstance.log.error(`[VoIP Push Send] 수신자 토큰이 없어 ${notificationKeyForLog} 푸시를 보낼 수 없습니다.`);
    return { success: false, error: 'Receiver token is missing' };
  }

  const notification = new apn.Notification();
  notification.topic = `${process.env.APN_BUNDLE_ID}.voip`; // VoIP 푸시용
  notification.priority = 10; // VoIP는 항상 10 (또는 5)
  notification.pushType = 'voip'; // VoIP 푸시 타입
  notification.expiry = Math.floor(Date.now() / 1000) + 3600; // 1시간 후 만료
  notification.payload = payload; // { aps: { ... }, ...customData }
  
  // fastifyInstance.log.info(`[VoIP Push Send] 전송 시도: ${notificationKeyForLog} (토큰 시작: ${receiverVoipToken.substring(0,10)}...)`);
  // fastifyInstance.log.info(`[VoIP Push Send] 알림 페이로드: ${JSON.stringify(notification.payload)}`);

  try {
    const result = await apnProvider.send(notification, receiverVoipToken);
    
    if (result.sent.length > 0) {
      // fastifyInstance.log.info(`[VoIP Push Send] 성공: ${notificationKeyForLog}`);
      return { success: true, result: result.sent };
    } 
    
    if (result.failed.length > 0) {
      const error = result.failed[0];
      fastifyInstance.log.error(`[VoIP Push Send] 실패: ${notificationKeyForLog}`, 
        JSON.stringify(error));
      fastifyInstance.log.error(`[VoIP Push Send] 상세 에러: 상태=${error.status}, 응답=${JSON.stringify(error.response)}, 오류=${error.error}`);
      
      return { success: false, error: error.response || error.error };
    }
    // 드물게 sent도 failed도 없는 경우가 있을 수 있음
    fastifyInstance.log.warn(`[VoIP Push Send] 알 수 없는 결과: ${notificationKeyForLog}`, JSON.stringify(result));
    return { success: false, error: 'Unknown APN send result' };

  } catch (error) {
    fastifyInstance.log.error(`[VoIP Push Send] 전송 중 예외 발생 (${notificationKeyForLog}):`, error);
    return { success: false, error: error.message };
  }
}

// 통화 푸시 알림 전송 엔드포인트
fastify.post('/api/v1/send-call-push', async (request, reply) => {
  const { caller_id, receiver_id } = request.body;

  if (!caller_id || !receiver_id) {
    return reply.code(400).send({ error: 'caller_id, receiver_id, caller_name은 필수입니다.' });
  }

  const callUUID = uuidv4(); // 통화 시도에 대한 고유 ID
  // fastify.log.info(`[send-call-push] 새 통화 요청: caller_id=${caller_id}, receiver_id=${receiver_id}, callUUID=${callUUID}`);

  // setTimeout 제거하고 즉시 처리
  let receiverVoipToken;
  try {
    const { data: receiverUser, error: fetchError } = await supabase
      .from('users')
      .select('voip_token, voice')
      .eq('auth_id', receiver_id)
      .single();

    if (fetchError || !receiverUser || !receiverUser.voip_token || !receiverUser.voice) {
      fastify.log.error(`[send-call-push] 수신자(ID: ${receiver_id}) 토큰 조회 실패 또는 없음:`, fetchError || '토큰 없음');
      return reply.code(400).send({ error: '수신자 토큰을 찾을 수 없습니다.' });
    }
    receiverVoipToken = receiverUser.voip_token;
    caller_name = "하우";
    
    const payload = {
      aps: { 'content-available': 1, 'sound': 'default' }, // 'sound'는 VoIP 알림 시 시스템 소리/진동 유도
      uuid: callUUID, // 통화 식별자 (클라이언트에서 CallKit 시작 시 사용)
      caller_id: caller_id,
      caller_name: caller_name,
      handle: caller_name, // CallKit에 표시될 발신자 정보
      notification_type: 'direct_call' // 알림 타입 명시
    };
    const notificationKeyForLog = `direct_call_to_${receiver_id}_from_${caller_id}`;
    
    // 함수화된 푸시 알림 로직 호출
    const pushResult = await sendVoipPushNotification(fastify, receiverVoipToken, payload, notificationKeyForLog);
    
    // 푸시 결과 로깅 및 응답
    if (pushResult.success) {
      // fastify.log.info(`[send-call-push] 푸시 전송 성공: ${notificationKeyForLog}, callUUID=${callUUID}`);
      return reply.send({ success: true, message: "통화 푸시가 성공적으로 전송되었습니다.", call_attempt_uuid: callUUID });
    } else {
      fastify.log.error(`[send-call-push] 푸시 전송 실패: ${notificationKeyForLog}, 오류:`, pushResult.error);
      return reply.code(500).send({ success: false, message: "통화 푸시 전송에 실패했습니다.", error: pushResult.error });
    }

  } catch (err) {
    fastify.log.error(`[send-call-push] 처리 중 예외 (수신자 ${receiver_id}):`, err);
    return reply.code(500).send({ success: false, message: "서버 내부 오류로 통화 푸시 전송에 실패했습니다." });
  }
});

// 테스트용 엔드포인트 - 등록된 토큰 목록 조회
fastify.get('/api/v1/tokens', async (request, reply) => {
  return { tokens: deviceTokens };
});

// 스케줄러 (매 5분 실행: 다음 5분간의 알림을 수집)
cron.schedule('*/5 * * * *', async () => {
  // fastify.log.info('5분 스케줄러 실행: 다음 5분간 알림 수집 시작');

  const now = new Date();
  const currentDayOfWeek = now.toLocaleDateString('ko-KR', { weekday: 'short', timeZone: 'Asia/Seoul' });
  // now.getTime() is UTC. We need to ensure comparisons are consistent.
  // For preciseScheduledTimeToday, we use local date parts but build a Date object, which will be in local TZ implicitly.
  // For fiveMinutesLater, we add to now (which is fine as it's a duration).
  const fiveMinutesLater = new Date(now.getTime() + 5 * 60000 - 1000); // Check up to 4:59 from now.
  const todayDateString = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Seoul"})).toISOString().split('T')[0]; // YYYY-MM-DD in KST

  try {
    const { data: users, error } = await supabase
      .from('users')
      .select('auth_id, call_time, voip_token, voice')
      .not('call_time', 'is', null)
      .neq('call_time', '');

    if (error) {
      fastify.log.error('5분 스케줄러 - 사용자 스케줄 조회 오류:', error);
      return;
    }

    if (users && users.length > 0) {
      for (const user of users) {
        if (!user.call_time || !user.voip_token || !user.voice) continue;
        // fastify.log.info(`5분 스케줄러 - 사용자 ${user.auth_id}의 스케줄 조회: ${user.call_time}`);

        try {
          const schedules = JSON.parse(user.call_time);
          
          for (const schedule of schedules) { // schedule: {day: "수", time: "17:05"}
            if (!schedule.time || !schedule.day) {
                // fastify.log.warn(`잘못된 스케줄 형식: ${user.auth_id}, ${JSON.stringify(schedule)}`);
                continue;
            }
            const [hour, minute] = schedule.time.split(':').map(Number);
            if (isNaN(hour) || isNaN(minute)) {
                // fastify.log.warn(`잘못된 시간 형식: ${user.auth_id}, ${schedule.time}`);
                continue;
            }
            
            // Create Date object for schedule time in KST for today
            const KSTnow = new Date(new Date().toLocaleString("en-US", {timeZone: "Asia/Seoul"}));
            const preciseScheduledTimeTodayKST = new Date(KSTnow.getFullYear(), KSTnow.getMonth(), KSTnow.getDate(), hour, minute, 0, 0);


            // Compare schedule.day with currentDayOfWeek (already in KST)
            // Compare preciseScheduledTimeTodayKST with current KST time range
            const nowKSTForCompare = new Date(new Date().toLocaleString("en-US", {timeZone: "Asia/Seoul"}));
            const fiveMinutesLaterKST = new Date(nowKSTForCompare.getTime() + 5 * 60000 - 1000);


            if (
              schedule.day === currentDayOfWeek &&
              preciseScheduledTimeTodayKST.getTime() >= nowKSTForCompare.getTime() && 
              preciseScheduledTimeTodayKST.getTime() <= fiveMinutesLaterKST.getTime()
            ) {
              const notificationKey = `${user.auth_id}_${schedule.day}_${schedule.time}`;
              if (recentNotifications.get(notificationKey) === todayDateString) {
                // fastify.log.info(`5분 스케줄러 - 오늘 이미 발송된 알림 건너뜀: ${notificationKey}`);
                continue;
              }

              const alreadyInQueue = upcomingNotificationsToSend.some(
                task => task.notificationKey === notificationKey && task.preciseScheduledTime.getTime() === preciseScheduledTimeTodayKST.getTime()
              );
              if (alreadyInQueue) {
                // fastify.log.info(`5분 스케줄러 - 이미 발송 대기열에 존재: ${notificationKey}`);
                continue;
              }
              
              upcomingNotificationsToSend.push({
                userId: user.auth_id,
                voipToken: user.voip_token,
                userVoice: user.voice,
                originalScheduleDay: schedule.day,
                originalScheduleTime: schedule.time,
                preciseScheduledTime: preciseScheduledTimeTodayKST, // Store KST Date object
                notificationKey: notificationKey,
              });
              // fastify.log.info(`5분 스케줄러 - 알림 대기열 추가: ${notificationKey} for ${preciseScheduledTimeTodayKST.toLocaleTimeString('ko-KR', { timeZone: 'Asia/Seoul' })} (Voice: ${user.voice})`);
            }
          }
        } catch (parseError) {
          fastify.log.error(`5분 스케줄러 - 사용자 ${user.auth_id}의 call_time 파싱 오류:`, parseError, user.call_time);
        }
      }
    }
  } catch (err) {
    fastify.log.error('5분 스케줄러 작업 중 전체 오류:', err);
  }
}, {
  scheduled: true,
  timezone: "Asia/Seoul"
});

// 1분마다 실행되는 정밀 발송기

// 허용할 과거 스케줄 시간 (분 단위). 예를 들어 2분으로 설정하면,
// 현재 시간이 13:17일 때, 13:15, 13:16, 13:17에 예정되었던 미발송 알림을 처리 시도.
const PAST_SCHEDULE_TOLERANCE_MINUTES = 5; 

setInterval(async () => {
  const dispatchNowKST = new Date(new Date().toLocaleString("en-US", {timeZone: "Asia/Seoul"}));
  // 한국 시간 기준으로 현재 '분'을 정확히 표현 (초, 밀리초는 0으로)
  const currentMinuteMatchKST = new Date(dispatchNowKST.getFullYear(), dispatchNowKST.getMonth(), dispatchNowKST.getDate(), dispatchNowKST.getHours(), dispatchNowKST.getMinutes(), 0, 0);
  const todayDateStringKST = dispatchNowKST.toISOString().split('T')[0]; // YYYY-MM-DD in KST (though ISO is UTC, source is KST date parts)

  // 허용 범위 시작 시간 계산
  const toleranceStartTimeKST = new Date(currentMinuteMatchKST.getTime() - PAST_SCHEDULE_TOLERANCE_MINUTES * 60000);

  // Filter tasks based on KST times, including the tolerance for past schedules
  const notificationsDueThisPeriod = upcomingNotificationsToSend.filter(task => {
    const taskScheduledMinuteKST = new Date(task.preciseScheduledTime.getFullYear(), task.preciseScheduledTime.getMonth(), task.preciseScheduledTime.getDate(), task.preciseScheduledTime.getHours(), task.preciseScheduledTime.getMinutes(), 0, 0);
    // 작업의 예약 시간이 (현재 시간 - 허용 오차) ~ 현재 시간 사이인지 확인
    return taskScheduledMinuteKST.getTime() >= toleranceStartTimeKST.getTime() &&
           taskScheduledMinuteKST.getTime() <= currentMinuteMatchKST.getTime();
  });

  // if (notificationsDueThisPeriod.length > 0) {
  //   fastify.log.info(`1분 발송기 - ${dispatchNowKST.toLocaleTimeString('ko-KR', { timeZone: 'Asia/Seoul' })} 처리 대상 (과거 ${PAST_SCHEDULE_TOLERANCE_MINUTES}분 허용): ${notificationsDueThisPeriod.length}건`);
  // }

  for (const task of notificationsDueThisPeriod) { // 변수명 변경: notificationsDueThisMinute -> notificationsDueThisPeriod
    if (recentNotifications.get(task.notificationKey) === todayDateStringKST) {
      // fastify.log.info(`1분 발송기 - 오늘 이미 발송된 알림 건너뜀 (최종 체크): ${task.notificationKey}`);
      continue;
    }

    const scheduledCallUUID = uuidv4();
    const payload = { 
      aps: { 
        'content-available': 1, 
        'sound': 'default' 
      },
      uuid: scheduledCallUUID,
      caller_id: task.userId,           // 알림 받는 사용자 자신의 ID
      caller_name: "하우",
      handle: "하우",
      notification_type: 'direct_call', 
      
      // original_schedule_info: {
      //     user_id_reminded: task.userId,
      //     day: task.originalScheduleDay,
      //     time: task.originalScheduleTime,
      //     voice_used_for_caller: task.userVoice, // 어떤 voice가 사용되었는지 명시 (선택적)
      //     notification_key_internal: task.notificationKey
      // }
    };
    
    // 함수화된 푸시 알림 로직 호출
    const pushResult = await sendVoipPushNotification(fastify, task.voipToken, payload, task.notificationKey);

    if (pushResult.success) {
      // fastify.log.info(`1분 발송기 - 조용한 푸시 성공: ${task.notificationKey}`); // 함수 내부에서 로깅
      recentNotifications.set(task.notificationKey, todayDateStringKST);
    } else {
      // fastify.log.error(`1분 발송기 - 조용한 푸시 실패: ${task.notificationKey}`, pushResult.error); // 함수 내부에서 로깅
      // 실패 처리 로직 (예: 재시도 큐에 넣기 등) 고려 가능
    }
  }

  // 처리된(시간이 되었거나, 이미 성공적으로 발송된) 알림들을 대기열에서 제거
  upcomingNotificationsToSend = upcomingNotificationsToSend.filter(task => {
    if (recentNotifications.get(task.notificationKey) === todayDateStringKST) {
      return false; // 이미 오늘 성공적으로 발송됨
    }
    // 작업의 예약 시간이 (현재 시간의 시작 - 허용 오차) 보다 이전이면 제거
    // 즉, 허용된 과거 시간 범위보다 더 오래된 것은 제거
    const taskScheduledMinuteKST = new Date(task.preciseScheduledTime.getFullYear(), task.preciseScheduledTime.getMonth(), task.preciseScheduledTime.getDate(), task.preciseScheduledTime.getHours(), task.preciseScheduledTime.getMinutes(), 0, 0);
    if (taskScheduledMinuteKST.getTime() < toleranceStartTimeKST.getTime()) { 
      // fastify.log.info(`1분 발송기 - 대기열에서 매우 오래된 작업 제거: ${task.notificationKey} (예약: ${taskScheduledMinuteKST.toLocaleTimeString('ko-KR', {timeZone: 'Asia/Seoul'})}, 기준: ${toleranceStartTimeKST.toLocaleTimeString('ko-KR', {timeZone: 'Asia/Seoul'})})`);
      return false; 
    }
    return true; // 그 외에는 대기열에 유지
  });

}, 60000); // 60초(1분)마다 실행

// 회원 탈퇴 처리 엔드포인트
fastify.delete('/api/v1/user/delete', async (request, reply) => {
  // 인증 헤더에서 토큰 추출
  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.code(401).send({ error: '인증 토큰이 필요합니다.' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    // JWT 토큰으로 사용자 정보 확인
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    
    if (userError || !userData || !userData.user) {
      fastify.log.error(`토큰 검증 오류: ${userError?.message || '사용자 정보 없음'}`);
      return reply.code(401).send({ error: '유효하지 않은 토큰입니다.' });
    }
    
    const userId = userData.user.id;
    // fastify.log.info(`회원 탈퇴 요청: userId=${userId}`);

    // Supabase Auth API로 사용자 삭제
    // 관리자 권한으로 사용자 삭제 (service_role key 필요)
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    
    if (deleteError) {
      fastify.log.error(`회원 탈퇴 오류: ${deleteError.message}`);
      return reply.code(500).send({ 
        error: '회원 탈퇴 처리 중 오류가 발생했습니다.', 
        message: deleteError.message 
      });
    }
    
    // 1. history 테이블에서 사용자 데이터 삭제
    const { error: historyError } = await supabase
      .from('history')
      .delete()
      .eq('auth_id', userId);
      
    if (historyError) {
      fastify.log.warn(`history 테이블 데이터 삭제 오류: ${historyError.message}`);
      // 이 오류는 진행을 중단하지 않음
    }
    
    // 2. user_monthly_points 테이블에서 사용자 데이터 삭제
    const { error: pointsError } = await supabase
      .from('user_monthly_points')
      .delete()
      .eq('user_id', userId);
      
    if (pointsError) {
      fastify.log.warn(`user_monthly_points 테이블 데이터 삭제 오류: ${pointsError.message}`);
      // 이 오류는 진행을 중단하지 않음
    }
    
    // 3. users 테이블에서 사용자 데이터 삭제
    const { error: usersError } = await supabase
      .from('users')
      .delete()
      .eq('auth_id', userId);
      
    if (usersError) {
      fastify.log.warn(`users 테이블 데이터 삭제 오류: ${usersError.message}`);
      // 이 오류는 진행을 중단하지 않음
    }
    
    return reply.code(200).send({ 
      success: true, 
      message: '회원 탈퇴가 성공적으로 처리되었습니다.' 
    });
    
  } catch (error) {
    fastify.log.error(`회원 탈퇴 처리 중 오류 발생: ${error.message}`);
    return reply.code(500).send({ 
      error: '회원 탈퇴 처리 중 오류가 발생했습니다.', 
      message: error.message 
    });
  }
});

// 코인 잔액 확인 엔드포인트
fastify.get('/api/v1/coins/balance/:user_id', async (request, reply) => {
  const { user_id } = request.params;

  if (!user_id) {
    return reply.code(400).send({ error: 'user_id는 필수입니다.' });
  }

  try {
    const { data: userCoin, error } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (error && error.code !== 'PGRST116') { // PGRST116: No rows found
      fastify.log.error(`코인 잔액 조회 오류 (user: ${user_id}):`, error);
      return reply.code(500).send({ error: '코인 잔액 조회 중 오류가 발생했습니다.' });
    }

    const balance = userCoin ? userCoin.balance : 0;
    return { success: true, balance };

  } catch (err) {
    fastify.log.error(`코인 잔액 조회 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 코인 잔액 조회에 실패했습니다.' });
  }
});

// 코인 사용 (차감) 엔드포인트
fastify.post('/api/v1/coins/use', async (request, reply) => {
  const { user_id, amount, description } = request.body;

  if (!user_id || !amount || amount <= 0) {
    return reply.code(400).send({ error: 'user_id와 양수인 amount는 필수입니다.' });
  }

  try {
    // 1. 현재 잔액 확인
    const { data: userCoin, error: fetchError } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (fetchError) {
      if (fetchError.code === 'PGRST116') {
        // 사용자 코인 레코드가 없음
        return reply.code(400).send({ error: '코인 잔액이 부족합니다.' });
      }
      fastify.log.error(`코인 사용 - 잔액 조회 오류 (user: ${user_id}):`, fetchError);
      return reply.code(500).send({ error: '코인 잔액 조회 중 오류가 발생했습니다.' });
    }

    const currentBalance = userCoin.balance;
    if (currentBalance < amount) {
      return reply.code(400).send({ error: '코인 잔액이 부족합니다.' });
    }

    const newBalance = currentBalance - amount;

    // 2. 트랜잭션으로 잔액 업데이트 및 거래 기록 추가
    const { error: updateError } = await supabase
      .from('user_coins')
      .update({ balance: newBalance })
      .eq('user_id', user_id);

    if (updateError) {
      fastify.log.error(`코인 사용 - 잔액 업데이트 오류 (user: ${user_id}):`, updateError);
      return reply.code(500).send({ error: '코인 차감 중 오류가 발생했습니다.' });
    }

    // 3. 거래 기록 추가
    const { error: transactionError } = await supabase
      .from('coin_transactions')
      .insert({
        user_id: user_id,
        transaction_type: 'usage',
        amount: -amount,
        balance_after: newBalance,
        description: description || `코인 사용 (${amount} 차감)`
      });

    if (transactionError) {
      fastify.log.error(`코인 사용 - 거래 기록 오류 (user: ${user_id}):`, transactionError);
      // 거래 기록 실패는 치명적이지 않으므로 계속 진행
    }

    return reply.send({ 
      success: true, 
      message: '코인이 성공적으로 차감되었습니다.',
      balance: newBalance,
      used_amount: amount
    });

  } catch (err) {
    fastify.log.error(`코인 사용 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 코인 사용에 실패했습니다.' });
  }
});

// StoreKit 2 Transaction 기반 코인 충전 엔드포인트
fastify.post('/api/v1/coins/verify-and-charge', async (request, reply) => {
  const { user_id, product_id, transaction_id, purchase_date, environment, build_environment, verification_method } = request.body;

  if (!user_id || !product_id || !transaction_id) {
    return reply.code(400).send({ 
      error: 'user_id, product_id, transaction_id는 필수입니다.' 
    });
  }

  // StoreKit 2 Transaction 방식만 지원
  if (verification_method !== 'storekit2_transaction') {
    return reply.code(400).send({ 
      error: 'storekit2_transaction 방식만 지원됩니다.' 
    });
  }

  try {
    // 0. Rate Limiting 체크
    const rateLimitCheck = checkPurchaseRateLimit(user_id, transaction_id);
    if (!rateLimitCheck.allowed) {
      fastify.log.warn(`Rate limit 차단: user=${user_id}, transaction=${transaction_id}, reason=${rateLimitCheck.reason}`);
      return reply.code(429).send({ error: rateLimitCheck.reason });
    }

    // 1. 중복 거래 확인 (Transaction ID 기준)
    const { data: existingTransaction, error: duplicateCheckError } = await supabase
      .from('coin_transactions')
      .select('id, transaction_id')
      .eq('transaction_id', transaction_id)
      .single();

    if (existingTransaction) {
      fastify.log.warn(`중복 거래 시도: transaction_id=${transaction_id}, user=${user_id}`);
      return reply.code(400).send({ error: '이미 처리된 거래입니다.' });
    }

    if (duplicateCheckError && duplicateCheckError.code !== 'PGRST116') {
      fastify.log.error(`중복 거래 확인 오류: ${duplicateCheckError.message}`);
      return reply.code(500).send({ error: '거래 확인 중 오류가 발생했습니다.' });
    }

    // 2. ⚠️ App Store Server API 검증 - 클라이언트 환경 정보 사용
    const appleVerification = await verifyWithAppleServer(transaction_id, build_environment);
    
    if (!appleVerification.success) {
      fastify.log.error(`Apple 서버 검증 실패: transaction_id=${transaction_id}, error=${appleVerification.error}, build_env=${build_environment}`);
      return reply.code(400).send({ error: 'Apple 서버 검증에 실패했습니다. 유효하지 않은 거래입니다.' });
    }

    // Apple 서버 응답과 클라이언트 데이터 일치 확인
    if (appleVerification.data.productId !== product_id) {
      fastify.log.error(`상품 ID 불일치: client=${product_id}, apple=${appleVerification.data.productId}`);
      return reply.code(400).send({ error: '상품 정보가 일치하지 않습니다.' });
    }

    // Bundle ID 검증 추가
    const expectedBundleId = process.env.APPLE_BUNDLE_ID || process.env.APN_BUNDLE_ID;
    if (appleVerification.data.bundleId !== expectedBundleId) {
      fastify.log.error(`Bundle ID 불일치: expected=${expectedBundleId}, received=${appleVerification.data.bundleId}`);
      return reply.code(400).send({ error: '앱 정보가 일치하지 않습니다.' });
    }

    // 거래 상태 검증 (refunded, cancelled 등 체크)
    if (appleVerification.data.transactionReason === 'REFUND') {
      fastify.log.warn(`환불된 거래 시도: transaction_id=${transaction_id}`);
      return reply.code(400).send({ error: '환불된 거래입니다.' });
    }

    // 3. 거래 날짜 검증 (너무 오래된 거래 차단)
    const transactionDate = new Date(appleVerification.data.purchaseDate);
    const now = new Date();
    const maxAge = 24 * 60 * 60 * 1000; // 24시간
    
    if (now.getTime() - transactionDate.getTime() > maxAge) {
      fastify.log.warn(`오래된 거래 시도: transaction_id=${transaction_id}, date=${transactionDate}`);
      return reply.code(400).send({ error: '거래가 너무 오래되었습니다.' });
    }

    // 4. StoreKit 2 Transaction 검증 로깅
    fastify.log.info(`Apple 검증 성공: user=${user_id}, product=${product_id}, transaction=${transaction_id}, env=${appleVerification.data.environment}, build_env=${build_environment}`);

    // 5. Apple에서 확인된 상품 ID로 코인 수량 계산
    const coinAmount = getCoinAmountForProductId(appleVerification.data.productId);
    
    if (coinAmount === 0) {
      return reply.code(400).send({ error: '유효하지 않은 상품 ID입니다.' });
    }

    // 6. 코인 충전 처리 - 환경에 따른 description 설정
    let chargeDescription = "인앱구매";
    
    // Apple에서 확인된 환경 정보를 기반으로 테스트/실제 결제 구분
    if (appleVerification.data.environment === 'Sandbox') {
      chargeDescription = "인앱구매 (Sandbox)";
    } else if (appleVerification.data.environment === 'Production') {
      chargeDescription = "인앱구매";
    } else {
      // 클라이언트 빌드 환경 정보도 활용
      if (build_environment === 'development' || build_environment === 'testflight') {
        chargeDescription = "인앱구매 (Testflight)";
      } else {
        chargeDescription = "인앱구매";
      }
    }
    
    const chargeResult = await chargeCoinsToUser(
      user_id, 
      coinAmount, 
      chargeDescription,
      transaction_id
    );
    
    if (chargeResult.success) {
      // 성공 시 보안 로그
      fastify.log.info(`코인 충전 성공: user=${user_id}, amount=${coinAmount}, transaction=${transaction_id}, balance=${chargeResult.newBalance}, build_env=${build_environment}`);
      
      return reply.send({ 
        success: true, 
        message: 'Apple 서버 검증을 통해 코인이 성공적으로 충전되었습니다.',
        balance: chargeResult.newBalance,
        charged_amount: coinAmount,
        product_id: appleVerification.data.productId, // Apple에서 확인된 상품 ID 사용
        verification_method: 'apple_server_verified',
        detected_environment: appleVerification.data.environment
      });
    } else {
      return reply.code(500).send({ error: chargeResult.error });
    }

  } catch (err) {
    fastify.log.error(`코인 충전 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 검증에 실패했습니다.' });
  }
});

// App Store Server API 검증 함수 - 클라이언트 환경 정보 활용
async function verifyWithAppleServer(transactionId, clientBuildEnvironment = null) {
  try {
    // Apple API 인증 정보 확인 (App Store Server API 전용)
    const hasAppleAuth = (process.env.APPLE_KEY_ID || process.env.APN_KEY_ID) && 
                        (process.env.APPLE_TEAM_ID || process.env.APN_TEAM_ID) && 
                        (process.env.APPLE_BUNDLE_ID || process.env.APN_BUNDLE_ID) &&
                        (process.env.APPLE_KEY_PATH || process.env.APN_KEY_PATH);
    
    if (!hasAppleAuth) {
      return {
        success: false,
        error: 'Apple API 인증 정보가 설정되지 않았습니다. P8 파일 또는 환경변수를 확인하세요.'
      };
    }

    // 클라이언트 환경 정보에 따른 API 엔드포인트 결정
    let baseUrl;
    if (clientBuildEnvironment === 'testflight' || clientBuildEnvironment === 'development') {
      baseUrl = 'https://api.storekit-sandbox.itunes.apple.com';
      fastify.log.info(`TestFlight/Development 환경 감지: Sandbox API 사용`);
    } else if (clientBuildEnvironment === 'appstore') {
      baseUrl = 'https://api.storekit.itunes.apple.com';
      
    } else {
      // 클라이언트 환경 정보가 없으면 기존 로직 사용 (NODE_ENV 기반)
      baseUrl = process.env.NODE_ENV === 'production' 
        ? 'https://api.storekit.itunes.apple.com'
        : 'https://api.storekit-sandbox.itunes.apple.com';
      
    }
    
    const url = `${baseUrl}/inApps/v1/transactions/${transactionId}`;
    
    fastify.log.info(`Apple API 요청 시작:`, {
      url: url,
      transactionId: transactionId,
      clientBuildEnvironment: clientBuildEnvironment,
      nodeEnv: process.env.NODE_ENV
    });
    
    // JWT 토큰 생성
    const authToken = generateAppleJWT();
    
    const response = await axios.get(url, {
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'Content-Type': 'application/json'
      },
      timeout: 15000 // 15초 타임아웃
    });

    fastify.log.info(`Apple API 응답:`, {
      status: response.status,
      headers: response.headers,
      hasSignedTransactionInfo: !!response.data?.signedTransactionInfo
    });

    if (response.status === 200) {
      // JWS 응답 디코딩 및 검증
      const transactionInfo = decodeAndVerifyJWS(response.data.signedTransactionInfo);
      
      if (!transactionInfo) {
        return {
          success: false,
          error: 'Apple 거래 정보 검증에 실패했습니다.'
        };
      }

      // 거래 정보 상세 검증
      const validationResult = validateTransactionInfo(transactionInfo);
      if (!validationResult.valid) {
        return {
          success: false,
          error: validationResult.error
        };
      }
      
      // Bundle ID 검증
      const expectedBundleId = process.env.APPLE_BUNDLE_ID || process.env.APN_BUNDLE_ID;
      if (transactionInfo.bundleId !== expectedBundleId) {
        fastify.log.error(`Bundle ID 불일치: expected=${expectedBundleId}, received=${transactionInfo.bundleId}`);
        return {
          success: false,
          error: '앱 정보가 일치하지 않습니다.'
        };
      }
      
      return {
        success: true,
        data: {
          transactionId: transactionInfo.transactionId,
          originalTransactionId: transactionInfo.originalTransactionId,
          productId: transactionInfo.productId,
          bundleId: transactionInfo.bundleId,
          purchaseDate: transactionInfo.purchaseDate,
          environment: transactionInfo.environment,
          transactionReason: transactionInfo.transactionReason,
          type: transactionInfo.type,
          appAccountToken: transactionInfo.appAccountToken
        }
      };
    } else {
      return {
        success: false,
        error: `Apple API 응답 오류: ${response.status} - 거래를 찾을 수 없습니다.`
      };
    }

  } catch (error) {
    // 오류 정보를 더 자세히 로깅
    const errorDetails = {
      message: error.message,
      status: error.response?.status,
      statusText: error.response?.statusText,
      data: error.response?.data,
      requestUrl: error.config?.url,
      requestHeaders: error.config?.headers,
      code: error.code,
      clientBuildEnvironment: clientBuildEnvironment
    };
    
    fastify.log.error('Apple API 요청 중 오류:', errorDetails);

    if (error.response) {
      // Apple API 에러 응답
      if (error.response.status === 404) {
        return {
          success: false,
          error: '존재하지 않는 거래 ID입니다.'
        };
      } else if (error.response.status === 401) {
        return {
          success: false,
          error: 'Apple API 인증에 실패했습니다.'
        };
      } else if (error.response.status === 403) {
        return {
          success: false,
          error: 'Apple API 권한이 없습니다. App Store Connect에서 API 키 권한을 확인하세요.'
        };
      } else {
        return {
          success: false,
          error: `Apple API 오류: ${error.response.status} - ${error.response.statusText}`
        };
      }
    } else if (error.code === 'ECONNABORTED') {
      return {
        success: false,
        error: 'Apple 서버 응답 시간 초과'
      };
    } else {
      return {
        success: false,
        error: `Apple 서버 통신 오류: ${error.message}`
      };
    }
  }
}

// 거래 정보 상세 검증
function validateTransactionInfo(transactionInfo) {
  // 1. 필수 필드 확인
  if (!transactionInfo.transactionId || !transactionInfo.productId || !transactionInfo.bundleId) {
    return { valid: false, error: '거래 정보가 불완전합니다.' };
  }

  // 2. Bundle ID 검증
  if (transactionInfo.bundleId !== process.env.APN_BUNDLE_ID) {
    return { valid: false, error: '앱 정보가 일치하지 않습니다.' };
  }

  // 3. 거래 유형 검증 (Auto-Renewable Subscription이 아닌 일반 인앱 구매여야 함)
  if (transactionInfo.type !== 'Non-Renewable Subscription' && transactionInfo.type !== 'Consumable') {
    // 실제로는 대부분 'Consumable'이어야 함
    fastify.log.warn(`예상과 다른 거래 유형: ${transactionInfo.type}`);
  }

  // 4. 환불되지 않은 거래인지 확인
  if (transactionInfo.transactionReason === 'REFUND') {
    return { valid: false, error: '환불된 거래입니다.' };
  }

  // 5. 거래 날짜 검증 (미래 날짜가 아닌지)
  const purchaseDate = new Date(transactionInfo.purchaseDate);
  if (purchaseDate > new Date()) {
    return { valid: false, error: '잘못된 구매 날짜입니다.' };
  }

  return { valid: true };
}

// Apple JWT 토큰 생성 (App Store Server API 전용)
function generateAppleJWT() {
  // APPLE_ 환경변수 우선, 없으면 APN_ 환경변수 사용
  const keyId = process.env.APPLE_KEY_ID || process.env.APN_KEY_ID;
  const teamId = process.env.APPLE_TEAM_ID || process.env.APN_TEAM_ID;
  const bundleId = process.env.APPLE_BUNDLE_ID || process.env.APN_BUNDLE_ID;
  const keyPath = process.env.APPLE_KEY_PATH || process.env.APN_KEY_PATH;

  if (!keyId || !teamId || !bundleId) {
    throw new Error('Apple API 인증 정보가 설정되지 않았습니다.');
  }

  const header = {
    alg: 'ES256',
    kid: keyId,
    typ: 'JWT'
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + (20 * 60), // 20분 만료
    aud: 'appstoreconnect-v1',
    bid: bundleId
  };

  // 디버깅: 사용 중인 인증 정보 로깅
  fastify.log.info(`Apple JWT 생성 시도:`, {
    keyId: keyId,
    teamId: teamId,
    bundleId: bundleId,
    keyPath: keyPath,
    usingDedicatedKey: !!process.env.APPLE_KEY_ID,
    payload: payload // JWT 페이로드도 출력
  });

  let privateKey;
  
  try {
    // 1. App Store Server API 전용 키 파일 우선 사용
    if (process.env.APPLE_KEY_PATH && fs.existsSync(process.env.APPLE_KEY_PATH)) {
      privateKey = fs.readFileSync(process.env.APPLE_KEY_PATH, 'utf8');
      fastify.log.info('App Store Server API 전용 P8 파일 로드: ' + process.env.APPLE_KEY_PATH);
    }
    // 2. APN 키 파일 사용 (대체)
    else if (keyPath && fs.existsSync(keyPath)) {
      privateKey = fs.readFileSync(keyPath, 'utf8');
      fastify.log.info('APN P8 파일에서 Apple 개인키 로드: ' + keyPath);
    }
    // 3. 기본 경로에서 AuthKey.p8 파일 찾기
    else if (fs.existsSync(path.join(__dirname, 'AuthKey.p8'))) {
      privateKey = fs.readFileSync(path.join(__dirname, 'AuthKey.p8'), 'utf8');
      fastify.log.info('기본 경로에서 Apple 개인키 로드: ./AuthKey.p8');
    }
    else {
      throw new Error('Apple 개인키를 찾을 수 없습니다. P8 파일 필요합니다.');
    }

    const token = jwt.sign(payload, privateKey, {
      algorithm: 'ES256',
      header: header
    });
    
    fastify.log.info(`JWT 토큰 생성 성공 (길이: ${token.length})`);
    return token;

  } catch (error) {
    fastify.log.error(`JWT 토큰 생성 실패: ${error.message}`);
    throw new Error(`JWT 토큰 생성 실패: ${error.message}`);
  }
}

// JWS 디코딩 및 검증 함수 (보안 강화)
function decodeAndVerifyJWS(jwsData) {
  try {
    // JWS 형식 검증
    const parts = jwsData.split('.');
    if (parts.length !== 3) {
      throw new Error('잘못된 JWS 형식');
    }

    // 헤더 디코딩
    const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString());
    
    // 페이로드 디코딩
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    
    // 기본적인 검증 (실제로는 Apple 공개키로 서명 검증 필요)
    if (!payload.transactionId || !payload.bundleId) {
      throw new Error('거래 정보가 불완전합니다.');
    }

    // 만료 시간 검증
    if (payload.signedDate) {
      const signedDate = new Date(payload.signedDate);
      const now = new Date();
      const maxAge = 24 * 60 * 60 * 1000; // 24시간
      
      if (now.getTime() - signedDate.getTime() > maxAge) {
        throw new Error('서명이 너무 오래되었습니다.');
      }
    }

    return payload;
    
  } catch (error) {
    fastify.log.error(`JWS 디코딩 오류: ${error.message}`);
    return null;
  }
}

// 상품 ID에 따른 코인 수량 반환
function getCoinAmountForProductId(productId) {
  const coinMapping = {
    'hau_product_22': 100,
    'hau_product_66': 315,
    'hau_product_154': 770,
    'hau_product_330': 1725,
    'hau_product_990': 5400
  };
  
  return coinMapping[productId] || 0;
}

// 공통 코인 충전 함수
async function chargeCoinsToUser(userId, amount, description, appleTransactionId = null) {
  try {
    // 1. 현재 잔액 확인 또는 새 레코드 생성
    const { data: userCoin, error: fetchError } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', userId)
      .single();

    let currentBalance = 0;
    let isNewUser = false;

    if (fetchError) {
      if (fetchError.code === 'PGRST116') {
        // 새 사용자 - 레코드 생성 필요
        isNewUser = true;
      } else {
        return { success: false, error: '코인 잔액 조회 중 오류가 발생했습니다.' };
      }
    } else {
      currentBalance = userCoin.balance;
    }

    const newBalance = currentBalance + amount;

    // 2. 잔액 업데이트 또는 새 레코드 생성
    if (isNewUser) {
      const { error: insertError } = await supabase
        .from('user_coins')
        .insert({
          user_id: userId,
          balance: newBalance
        });

      if (insertError) {
        return { success: false, error: '코인 충전 중 오류가 발생했습니다.' };
      }
    } else {
      const { error: updateError } = await supabase
        .from('user_coins')
        .update({ balance: newBalance })
        .eq('user_id', userId);

      if (updateError) {
        return { success: false, error: '코인 충전 중 오류가 발생했습니다.' };
      }
    }

    // 3. 거래 기록 추가 (Apple Transaction ID 포함)
    const transactionRecord = {
      user_id: userId,
      transaction_type: 'charge',
      amount: amount,
      balance_after: newBalance,
      description: description,
      transaction_id: appleTransactionId
    };

    const { error: transactionError } = await supabase
      .from('coin_transactions')
      .insert(transactionRecord);

    if (transactionError) {
      // 거래 기록 실패는 치명적이지 않으므로 경고만 로그
      fastify.log.warn(`거래 기록 오류 (user: ${userId}):`, transactionError);
    }

    return { success: true, newBalance };

  } catch (err) {
    fastify.log.error(`코인 충전 함수 오류 (user: ${userId}):`, err);
    return { success: false, error: '서버 내부 오류로 코인 충전에 실패했습니다.' };
  }
}

// 코인 충분 여부 확인 엔드포인트
fastify.post('/api/v1/coins/check-sufficient', async (request, reply) => {
  const { user_id, required_amount } = request.body;

  if (!user_id || !required_amount || required_amount <= 0) {
    return reply.code(400).send({ error: 'user_id와 양수인 required_amount는 필수입니다.' });
  }

  try {
    const { data: userCoin, error } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (error && error.code !== 'PGRST116') {
      fastify.log.error(`코인 충분성 확인 오류 (user: ${user_id}):`, error);
      return reply.code(500).send({ error: '코인 잔액 확인 중 오류가 발생했습니다.' });
    }

    const balance = userCoin ? userCoin.balance : 0;
    const isSufficient = balance >= required_amount;

    return reply.send({ 
      success: true, 
      is_sufficient: isSufficient,
      current_balance: balance,
      required_amount: required_amount,
      shortage: isSufficient ? 0 : required_amount - balance
    });

  } catch (err) {
    fastify.log.error(`코인 충분성 확인 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 코인 확인에 실패했습니다.' });
  }
});

// 통화 시작 엔드포인트 (거래 기록 생성)
fastify.post('/api/v1/coins/call/start', async (request, reply) => {
  const { user_id, description } = request.body;

  if (!user_id) {
    return reply.code(400).send({ error: 'user_id는 필수입니다.' });
  }

  try {
    // 현재 잔액 확인
    const { data: userCoin, error: fetchError } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (fetchError) {
      if (fetchError.code === 'PGRST116') {
        return reply.code(400).send({ error: '코인 잔액이 부족합니다.' });
      }
      fastify.log.error(`통화 시작 - 잔액 조회 오류 (user: ${user_id}):`, fetchError);
      return reply.code(500).send({ error: '코인 잔액 조회 중 오류가 발생했습니다.' });
    }

    const currentBalance = userCoin.balance;
    const firstMinuteCost = 10; // 첫 번째 분 비용
    
    if (currentBalance < firstMinuteCost) {
      return reply.code(400).send({ error: '코인 잔액이 부족합니다.' });
    }

    const newBalance = currentBalance - firstMinuteCost;

    // 잔액 업데이트 (첫 번째 분 코인 차감)
    const { error: updateError } = await supabase
      .from('user_coins')
      .update({ balance: newBalance })
      .eq('user_id', user_id);

    if (updateError) {
      fastify.log.error(`통화 시작 - 잔액 업데이트 오류 (user: ${user_id}):`, updateError);
      return reply.code(500).send({ error: '코인 차감 중 오류가 발생했습니다.' });
    }

    // 통화 거래 기록 생성 (첫 번째 분 비용으로 시작)
    const { data: transaction, error: transactionError } = await supabase
      .from('coin_transactions')
      .insert({
        user_id: user_id,
        transaction_type: 'usage',
        amount: -firstMinuteCost,
        balance_after: newBalance,
        description: description || '통화 1분 (10 코인 사용)'
      })
      .select()
      .single();

    if (transactionError) {
      fastify.log.error(`통화 시작 - 거래 기록 생성 오류 (user: ${user_id}):`, transactionError);
      return reply.code(500).send({ error: '통화 시작 중 오류가 발생했습니다.' });
    }

    return reply.send({ 
      success: true, 
      message: '통화가 시작되었습니다.',
      transaction_id: transaction.id,
      current_balance: newBalance,
      initial_cost: firstMinuteCost
    });

  } catch (err) {
    fastify.log.error(`통화 시작 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 통화 시작에 실패했습니다.' });
  }
});

// 통화 중 코인 차감 업데이트 엔드포인트
fastify.post('/api/v1/coins/call/update', async (request, reply) => {
  const { user_id, transaction_id, total_amount, description } = request.body;

  if (!user_id || !transaction_id || !total_amount || total_amount <= 0) {
    return reply.code(400).send({ error: 'user_id, transaction_id, total_amount는 필수입니다.' });
  }

  try {
    // 현재 잔액 확인
    const { data: userCoin, error: fetchError } = await supabase
      .from('user_coins')
      .select('balance')
      .eq('user_id', user_id)
      .single();

    if (fetchError || !userCoin) {
      fastify.log.error(`통화 업데이트 - 잔액 조회 오류 (user: ${user_id}):`, fetchError);
      return reply.code(500).send({ error: '코인 잔액 조회 중 오류가 발생했습니다.' });
    }

    // 기존 거래 기록 조회하여 이전 차감 금액 확인
    const { data: existingTransaction, error: transactionFetchError } = await supabase
      .from('coin_transactions')
      .select('amount, balance_after')
      .eq('id', transaction_id)
      .eq('user_id', user_id)
      .single();

    if (transactionFetchError || !existingTransaction) {
      fastify.log.error(`통화 업데이트 - 기존 거래 조회 오류 (user: ${user_id}, transaction: ${transaction_id}):`, transactionFetchError);
      return reply.code(400).send({ error: '유효하지 않은 거래 ID입니다.' });
    }

    // 이전 차감 금액과 현재 총 차감 금액의 차이 계산
    const previousAmount = Math.abs(existingTransaction.amount);
    const additionalAmount = total_amount - previousAmount;
    
    if (additionalAmount < 0) {
      return reply.code(400).send({ error: '총 차감 금액이 이전 금액보다 작을 수 없습니다.' });
    }

    // 현재 잔액에서 추가 차감 가능한지 확인
    if (userCoin.balance < additionalAmount) {
      return reply.code(400).send({ error: '코인 잔액이 부족합니다.' });
    }

    const newBalance = userCoin.balance - additionalAmount;

    // 잔액 업데이트 (추가 차감 금액만큼)
    if (additionalAmount > 0) {
      const { error: updateError } = await supabase
        .from('user_coins')
        .update({ balance: newBalance })
        .eq('user_id', user_id);

      if (updateError) {
        fastify.log.error(`통화 업데이트 - 잔액 업데이트 오류 (user: ${user_id}):`, updateError);
        return reply.code(500).send({ error: '코인 차감 중 오류가 발생했습니다.' });
      }
    }

    // 거래 기록 업데이트 (총 차감 금액으로)
    const { error: transactionUpdateError } = await supabase
      .from('coin_transactions')
      .update({
        amount: -total_amount,
        balance_after: newBalance,
        description: description || `통화 진행 중 (총 ${total_amount} 코인 사용)`
      })
      .eq('id', transaction_id)
      .eq('user_id', user_id);

    if (transactionUpdateError) {
      fastify.log.error(`통화 업데이트 - 거래 기록 업데이트 오류 (user: ${user_id}):`, transactionUpdateError);
      return reply.code(500).send({ error: '거래 기록 업데이트 중 오류가 발생했습니다.' });
    }

    return reply.send({ 
      success: true, 
      message: '통화 진행 상황이 업데이트되었습니다.',
      current_balance: newBalance,
      total_used: total_amount,
      additional_used: additionalAmount
    });

  } catch (err) {
    fastify.log.error(`통화 업데이트 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 통화 업데이트에 실패했습니다.' });
  }
});

// 코인 거래 내역 조회 엔드포인트
fastify.get('/api/v1/coins/transactions/:user_id', async (request, reply) => {
  const { user_id } = request.params;
  const { page = 1, limit = 20 } = request.query;

  if (!user_id) {
    return reply.code(400).send({ error: 'user_id는 필수입니다.' });
  }

  try {
    const offset = (page - 1) * limit;

    // 거래 내역 조회 (최신순)
    const { data: transactions, error, count } = await supabase
      .from('coin_transactions')
      .select('*', { count: 'exact' })
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      fastify.log.error(`거래 내역 조회 오류 (user: ${user_id}):`, error);
      return reply.code(500).send({ error: '거래 내역 조회 중 오류가 발생했습니다.' });
    }

    return reply.send({ 
      success: true,
      transactions: transactions || [],
      pagination: {
        current_page: parseInt(page),
        per_page: parseInt(limit),
        total_count: count || 0,
        total_pages: Math.ceil((count || 0) / limit)
      }
    });

  } catch (err) {
    fastify.log.error(`거래 내역 조회 중 예외 발생 (user: ${user_id}):`, err);
    return reply.code(500).send({ error: '서버 내부 오류로 거래 내역 조회에 실패했습니다.' });
  }
});

// 구매 시도 제한 체크 함수
function checkPurchaseRateLimit(userId, transactionId) {
  const now = Date.now();
  const userKey = `purchase_${userId}`;
  const transactionKey = `transaction_${transactionId}`;
  
  // 사용자별 구매 제한 (1분에 최대 3번)
  const userAttempts = purchaseAttempts.get(userKey) || [];
  const recentUserAttempts = userAttempts.filter(time => now - time < 60000);
  
  if (recentUserAttempts.length >= 3) {
    return { allowed: false, reason: '구매 시도가 너무 빈번합니다. 잠시 후 다시 시도해주세요.' };
  }
  
  // Transaction ID별 중복 요청 제한 (5분 내 같은 Transaction ID 요청 차단)
  const transactionAttempts = purchaseAttempts.get(transactionKey) || [];
  const recentTransactionAttempts = transactionAttempts.filter(time => now - time < 300000);
  
  if (recentTransactionAttempts.length >= 1) {
    return { allowed: false, reason: '동일한 거래가 이미 처리 중입니다.' };
  }
  
  // 시도 기록 저장
  purchaseAttempts.set(userKey, [...recentUserAttempts, now]);
  purchaseAttempts.set(transactionKey, [...recentTransactionAttempts, now]);
  
  // 오래된 기록 정리 (메모리 절약)
  setTimeout(() => {
    const cleanUserAttempts = (purchaseAttempts.get(userKey) || []).filter(time => Date.now() - time < 60000);
    const cleanTransactionAttempts = (purchaseAttempts.get(transactionKey) || []).filter(time => Date.now() - time < 300000);
    
    if (cleanUserAttempts.length > 0) {
      purchaseAttempts.set(userKey, cleanUserAttempts);
    } else {
      purchaseAttempts.delete(userKey);
    }
    
    if (cleanTransactionAttempts.length > 0) {
      purchaseAttempts.set(transactionKey, cleanTransactionAttempts);
    } else {
      purchaseAttempts.delete(transactionKey);
    }
  }, 60000);
  
  return { allowed: true };
}

// 카카오톡 채널 챗봇 엔드포인트

// 챗봇 채팅
fastify.post('/api/v1/kakao/chat', async (request, reply) => {
  // OpenAI API 키 환경 변수에서 가져오기
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    reply.code(500).send({ error: 'OpenAI API 키가 설정되지 않았습니다.' });
    return;
  }

  console.log(request.body.userRequest.utterance);

  // OpenAI API 엔드포인트 및 요청 데이터
  const url = 'https://api.openai.com/v1/responses';
  const data = {
      model: 'gpt-4o-mini',
      input: request.body.userRequest.utterance,
  };
  const headers = {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
  };

  try {
      // OpenAI API로 POST 요청 보내기
      const response = await axios.post(url, data, { headers });

      console.log(response.data.output.content);

      // OpenAI API 응답을 클라이언트로 전달
      const outputObject = {
        "version": "2.0",
        "template": {
            "outputs": [
                {
                    "simpleText": {
                        "text": response.data.output.content[0].text
                    }
                }
            ]
        }
      }
      reply.send(outputObject);

  } catch (error) {
      fastify.log.error(error.response ? error.response.data : error.message); // 에러 로깅 개선
      // 에러 응답 처리
      reply.code(error.response ? error.response.status : 500).send({
          error: '오류가 발생했습니다.',
          details: error.response ? error.response.data : error.message,
      });
  }
});

// 서버 시작 (환경변수로 포트 설정)
const PORT = process.env.PORT || 3000;
fastify.listen({ port: parseInt(PORT), host: '0.0.0.0' }, (err, address) => {
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
  fastify.log.info(`서버가 ${address} 에서 실행 중입니다. (포트: ${PORT})`);
});

// 서버 종료 시 APN 제공자 종료
process.on('SIGINT', () => {
  if (apnProvider) {
    apnProvider.shutdown();
  }
  process.exit(0);
});