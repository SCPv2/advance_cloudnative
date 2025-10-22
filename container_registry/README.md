# Container Registry 구성

## 선행 실습

### 필수 '[Kubernetes Engine 생성 및 구성](../kubernetes_engine/README.md)'

- Kubernetes 클러스터 기본 이해

## 실습 환경 배포

**&#128906; 사용자 환경 구성 (\advance_cloudnative\kubernetes_engine\env_setup.ps1)**

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## 환경 검토

Security Group Rules

|Resource|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|bastionVM|bastionSG|Inbound|Your Public IP|TCP 22|SSH inbound from user PC|
|bastionVM|bastionSG|Outbound|0.0.0.0/0|TCP 80, 443|HTTP/HTTPS outbound to Internet|
|bastionVM|bastionSG|Outbound|0.0.0.0/0|TCP 6443|Kubernetes API Server access|
|Kubernetes|K8sSG|Inbound|0.0.0.0/0|TCP 80|HTTP inbound for services|
|Kubernetes|K8sSG|Outbound|0.0.0.0/0|TCP 80, 443|HTTP/HTTPS outbound to Internet|

## Container Registry 생성

-레지스트리명 : `cecr`

- 엔드포인트 : 프라이빗
- 엔드포인트 접근 제어 : 사용
  - bastionVM110r
  - Kubernetes Engine 노드 (cek8s 클러스터)

## Repository 생성

- 레지스트리 : cecr

- 리포지토리명 : `ceweb`
- 이미지 스캔 > 자동 스캔 : 사용 , 스캔 제외 정책 : 사용 안함
- 이미지 Pull 제한 : 사용 안함
- 이미지 잠금 여부 : 사용 안함
- 이미지 태그 삭제 : 삭제 정책 비활성화

## Bastion Server 접속 및 Docker 설치

**&#128906; Docker 설치**

```bash
# Docker 설치 스크립트 다운로드 및 실행(Docker가 설치되어 있지 않은 경우)
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl start docker
sudo systemctl enable --now docker

# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# 로그아웃 후 재로그인 (또는 newgrp docker)
newgrp docker

# Docker 설치 확인
docker version
```

## Container Registry 로그인

**&#128906; 인증키를 사용한 Registry 로그인**

```bash
# 레지스트리에 Login

docker login cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com

# Username: AccessKey ID 입력
# Password: Secret Access Key 입력

# 다음 명령어를 이용하여 Container Registry에 Image를 Push할 수 있습니다.
# docker tag 명령어를 이용하여 Image를 태깅 할 수 있습니다.

docker tag image:1 cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>
docker push cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>

#다음 명령어를 이용하여 Container Registry에서 Image를 Pull할 수 있습니다.

$ docker pull cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>
```

## Container App 빌드

### 작업 디렉토리로 이동

```bash
cd /home/rocky/advance_cloudnative/container_registry/k8s_app_deployment
```

### Web Server 이미지 빌드

- **Base Image**: nginx:alpine (경량 이미지)

- **사용자**: rocky:1000:1000 (비루트 사용자)
- **포트**: 8080 (비특권 포트)
- **기능**: Git 설치, Nginx 설정, Health check

```bash
# Web Server (Nginx) 이미지 빌드
docker build -f dockerfiles/Dockerfile.web -t creative-energy-web:latest .

# 빌드 확인
docker images | grep creative-energy-web
```

### App Server 이미지 빌드

- **Base Image**: node:18-alpine (Multi-stage 빌드)

- **사용자**: rocky:1001:1001 (비루트 사용자)
- **포트**: 3000
- **기능**: Git clone, npm install, Health check
- **빌드 방식**: Multi-stage (Git clone → Build → Runtime)
  - **Stage 1**: Git clone - 소스코드 다운로드
  - **Stage 2**: Build - npm install 및 의존성 설치
  - **Stage 3**: Runtime - 최종 실행 이미지 (최적화)

```bash
# App Server (Node.js) 이미지 빌드 - Multi-stage 방식
docker build -f dockerfiles/Dockerfile.app -t creative-energy-app:latest .

# 또는 configmap 태그로 빌드 (ConfigMap 기반 설정)
docker build -f dockerfiles/Dockerfile.app -t creative-energy-app:configmap .

# 빌드 확인
docker images | grep creative-energy-app
```

### 이미지 태그 지정

```bash
# Container Registry URL
REGISTRY_URL="cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com"

# Web 이미지 태그 지정
docker tag creative-energy-web:latest ${REGISTRY_URL}/ceweb/creative-energy-web:latest
docker tag creative-energy-web:latest ${REGISTRY_URL}/ceweb/creative-energy-web:v1.0

# App 이미지 태그 지정 (configmap 태그 포함)
docker tag creative-energy-app:latest ${REGISTRY_URL}/ceweb/creative-energy-app:latest
docker tag creative-energy-app:configmap ${REGISTRY_URL}/ceweb/creative-energy-app:configmap
docker tag creative-energy-app:latest ${REGISTRY_URL}/ceweb/creative-energy-app:v1.0

# 태그 확인
docker images | grep ${REGISTRY_URL}
```

### Container Registry에 푸시

```bash
# Web 이미지 푸시
REGISTRY_URL="cecr-xxxxx.scr.private.kr-west1.e.samsungsdscloud.com"
echo "Pushing Web server image..."
docker push ${REGISTRY_URL}/ceweb/creative-energy-web:latest
docker push ${REGISTRY_URL}/ceweb/creative-energy-web:v1.0

# App 이미지 푸시 (configmap 태그 포함)
echo "Pushing App server image..."
docker push ${REGISTRY_URL}/ceweb/creative-energy-app:latest
docker push ${REGISTRY_URL}/ceweb/creative-energy-app:configmap
docker push ${REGISTRY_URL}/ceweb/creative-energy-app:v1.0
```

### 이미지 푸시 확인

- Container Registry에서 이미지 목록 확인 (SCP 콘솔에서 확인)

```bash
# 로컬 이미지 정리 (선택사항)
docker system prune -f
```

### 자동화 스크립트 사용

**빌드 스크립트 사용:**

```bash
# 자동화된 이미지 빌드
./scripts/build-images.sh

# 이미지 푸시
./scripts/push-images.sh

# Git 기반 App 이미지 빌드 (Multi-stage)
./scripts/build-app-gitbased.sh
```

**스크립트별 기능:**

- `build-images.sh`: Web/App 이미지 일괄 빌드
- `push-images.sh`: Registry에 이미지 일괄 푸시
- `build-app-gitbased.sh`: Git clone 기반 App 이미지 빌드
