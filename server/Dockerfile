# Dockerfile

# Node.js 경량 이미지를 사용 (예: node:14-alpine)
FROM node:14-alpine

# 작업 디렉토리 생성
WORKDIR /app

# package.json 및 package-lock.json 복사 후 의존성 설치
COPY package*.json ./
RUN npm install

# 애플리케이션 소스 복사
COPY . .

# 서버가 사용하는 포트 노출 (예: 3000)
EXPOSE 3000

# 애플리케이션 실행 명령어 (예: websocket 서버 실행)
CMD ["npm", "start"]
