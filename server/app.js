const fastify = require('fastify')({ logger: true });
const axios = require('axios');

require('dotenv').config();

// 기본 HTTP 라우터 (테스트용)
fastify.get('/', async (request, reply) => {
  return { message: 'Fastify 서버가 동작 중입니다.' };
});

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

// 서버 시작 (포트 3000)
fastify.listen({ port: 3000, host: '0.0.0.0' }, (err, address) => {
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
  fastify.log.info(`서버가 ${address} 에서 실행 중입니다.`);
});