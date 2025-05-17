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

// APN 제공자 초기화 함수
function initializeAPNProvider() {
  try {
    // 토큰 기반 인증 방식 사용
    if (process.env.APN_KEY_ID && process.env.APN_TEAM_ID && process.env.APN_BUNDLE_ID) {
      const options = {
        token: {
          key: process.env.APN_KEY_CONTENT || process.env.APN_KEY_PATH || path.join(__dirname, 'AuthKey.p8'),
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

  // 기본 프롬프트 가져오기
  const basePrompt = fs.readFileSync(path.join(__dirname, 'prompt.txt'), 'utf8');
  
  // 클라이언트에서 보낸 사용자 정보 추출
  const { user_name, birthdate, self_intro, voice, history, language = 'ko' } = request.body || {};
  
  // 사용자 정보를 프롬프트에 추가
  let customPrompt = basePrompt;
  
  // 사용자별 맞춤형 프롬프트 작성
  if (user_name) {
    customPrompt = customPrompt.replace(/상대방/g, `${user_name}님`);
  }
  
  // 사용자 정보 섹션 추가
  let userInfo = "\n\n'''";
  userInfo += "\n[사용자 정보]";
  if (user_name) userInfo += `\n- 사용자의 이름은 "${user_name}"입니다.`;
  if (birthdate) userInfo += `\n- 사용자의 생년월일은 "${birthdate}"입니다.`;
  if (self_intro) userInfo += `\n- 사용자 소개: "${self_intro}"`;
  userInfo += "\n'''";

    let historyString = ""; // 새로운 변수 선언
    if (history) {
        // Supabase에서 가져온 history 배열을 문자열로 변환
        const historyText = history.map(record => 
            `- ${record.created_at}: ${record.transcript || '내용 없음'}`
        ).join("\n");
        historyString = `\n\n[이전 통화 기록]\n${historyText}`;
    }
    console.log("history", historyString);

    let background = "";
    if (voice === "Beomsoo") {
        background = "당신의 이름은 '범수'이며 30대 중반 남성이고 직업은 드라마 PD입니다.\n"
    } else if (voice === "Jinjoo") {
        background = "당신의 이름은 '진주'이며 30대 초반 여성이고 직업은 드라마 작가입니다.\n"
    }
    
    // 최종 프롬프트 생성
    const finalPrompt = background + customPrompt + userInfo + historyString; // 수정된 변수 사용
    
    console.log(`사용자 설정: 이름=${user_name}, 음성=${voice || 'ash'}, 언어=${language}`);

    let apiVoice = 'ash';
    if (voice === "Beomsoo") {
        apiVoice = "ash";
    } else if (voice === "Jinjoo") {
        apiVoice = "alloy";
    } else {
        apiVoice = voice || "ash";
    }
    
    // OpenAI API 엔드포인트 및 요청 데이터
    const url = 'https://api.openai.com/v1/realtime/sessions';
    const data = {
        model: 'gpt-4o-mini-realtime-preview',
        modalities: ['audio', 'text'],
        instructions: finalPrompt,
        // 'alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', and 'verse'
        voice: apiVoice,
        input_audio_transcription: {
            language: language,
            model: 'whisper-1'
        },
        tools: [
            {
                type: "function",
                name: "endCall",
                description: "상대방이 통화 종료의 의사를 밝히거나 어떤 이유로 통화를 종료해야하는 경우, 통화를 종료하려면 이 함수를 호출하세요."
            }
        ],
        tool_choice: "auto",
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

    fastify.log.info(`Supabase users 테이블 토큰 등록/업데이트: user_id=${user_id}, type=${token_type}, token=${device_token}`);
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

  try {
    fastifyInstance.log.info(`[VoIP Push Send] 전송 시도: ${notificationKeyForLog} (토큰: ${receiverVoipToken.substring(0,10)}...)`);
    const result = await apnProvider.send(notification, receiverVoipToken);
    
    if (result.sent.length > 0) {
      fastifyInstance.log.info(`[VoIP Push Send] 성공: ${notificationKeyForLog}`);
      return { success: true, result: result.sent };
    } 
    
    if (result.failed.length > 0) {
      fastifyInstance.log.error(`[VoIP Push Send] 실패: ${notificationKeyForLog}`, result.failed[0].response || result.failed[0].error);
      return { success: false, error: result.failed[0].response || result.failed[0].error };
    }
    // 드물게 sent도 failed도 없는 경우가 있을 수 있음
    fastifyInstance.log.warn(`[VoIP Push Send] 알 수 없는 결과: ${notificationKeyForLog}`, result);
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

  setTimeout(async () => {
    let receiverVoipToken;
    try {
      const { data: receiverUser, error: fetchError } = await supabase
        .from('users')
        .select('voip_token, voice')
        .eq('auth_id', receiver_id)
        .single();

      if (fetchError || !receiverUser || !receiverUser.voip_token || !receiverUser.voice) {
        fastify.log.error(`[send-call-push] 수신자(ID: ${receiver_id}) 토큰 조회 실패 또는 없음:`, fetchError || '토큰 없음');
        return;
      }
      receiverVoipToken = receiverUser.voip_token;
      caller_name = receiverUser.voice;
      
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
      await sendVoipPushNotification(fastify, receiverVoipToken, payload, notificationKeyForLog);
      // 결과 로깅은 sendVoipPushNotification 함수 내부에서 처리

    } catch (err) {
      fastify.log.error(`[send-call-push] 처리 중 예외 (수신자 ${receiver_id}):`, err);
    }
  }, 1000);

  return reply.send({ success: true, message: "통화 푸시 요청이 접수되었습니다.", call_attempt_uuid: callUUID });
});

// 테스트용 엔드포인트 - 등록된 토큰 목록 조회
fastify.get('/api/v1/tokens', async (request, reply) => {
  return { tokens: deviceTokens };
});

// 스케줄러 (매 5분 실행: 다음 5분간의 알림을 수집)
cron.schedule('*/5 * * * *', async () => {
  fastify.log.info('5분 스케줄러 실행: 다음 5분간 알림 수집 시작');

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
        fastify.log.info(`5분 스케줄러 - 사용자 ${user.auth_id}의 스케줄 조회: ${user.call_time}`);

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
              fastify.log.info(`5분 스케줄러 - 알림 대기열 추가: ${notificationKey} for ${preciseScheduledTimeTodayKST.toLocaleTimeString('ko-KR', { timeZone: 'Asia/Seoul' })} (Voice: ${user.voice})`);
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

  if (notificationsDueThisPeriod.length > 0) {
    fastify.log.info(`1분 발송기 - ${dispatchNowKST.toLocaleTimeString('ko-KR', { timeZone: 'Asia/Seoul' })} 처리 대상 (과거 ${PAST_SCHEDULE_TOLERANCE_MINUTES}분 허용): ${notificationsDueThisPeriod.length}건`);
  }

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
      caller_name: task.userVoice,      // 사용자의 voice 정보
      handle: task.userVoice,           // 사용자의 voice 정보
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
      fastify.log.info(`1분 발송기 - 대기열에서 매우 오래된 작업 제거: ${task.notificationKey} (예약: ${taskScheduledMinuteKST.toLocaleTimeString('ko-KR', {timeZone: 'Asia/Seoul'})}, 기준: ${toleranceStartTimeKST.toLocaleTimeString('ko-KR', {timeZone: 'Asia/Seoul'})})`);
      return false; 
    }
    return true; // 그 외에는 대기열에 유지
  });

}, 60000); // 60초(1분)마다 실행

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