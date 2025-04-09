# Makefile

.PHONY: build run re

# Docker 이미지 빌드
build:
	docker build -t my-node-server .

# Docker 컨테이너 실행 (포트 매핑: 로컬 3000 -> 컨테이너 3000)
run:
	docker run -p 3000:3000 --name my-node-container my-node-server

# 빌드 후 실행 (기존 컨테이너 삭제 후 실행)
re: build
	@echo "기존 컨테이너 중지 및 삭제..."
	-docker stop my-node-container 2>/dev/null
	-docker rm my-node-container 2>/dev/null
	@echo "새 컨테이너 실행..."
	docker run -d -p 3000:3000 --name my-node-container my-node-server

log:
	docker logs -f my-node-container

stop:
	docker stop my-node-container

shell:
	docker exec -it my-node-container sh

