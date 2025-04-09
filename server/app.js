const http = require('http');

const PORT = process.env.PORT || 3000;

const requestHandler = (req, res) => {
  console.log(`요청 URL: ${req.url}`);
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello, World!\n');
};

const server = http.createServer(requestHandler);

server.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다!`);
});
