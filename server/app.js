'use strict'

const fastify = require('fastify')({ logger: true });
const websocket = require('@fastify/websocket');
fastify.register(websocket);

fastify.register(async function (fastify) {
  fastify.get('/ws', { websocket: true }, (socket /* SocketStream */, req /* FastifyRequest */) => {
    console.log('Client connected');
  
    socket.on('message', message => {
      console.log("message on");
      socket.send(message);
    });
  
    socket.on('close', () => {
      console.log('Client disconnected');
    });
  
    socket.on('error', err => {
      console.error('WebSocket error:', err);
    });
  });
})

// 기본 HTTP 라우터 (테스트용)
fastify.get('/', async (request, reply) => {
  return { message: 'Fastify 웹소켓 서버가 동작 중입니다.' };
});

// 서버 시작 (포트 3000)
fastify.listen({ port: 3000, host: '0.0.0.0' }, (err, address) => {
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
  fastify.log.info(`서버가 ${address} 에서 실행 중입니다.`);
});