# Container Registry 구성 및 관리

## 선행 실습

### 필수 '[과정 소개](https://github.com/SCPv2/ce_advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 필수 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

### 권장 '[Kubernetes Engine 생성 및 구성](../kubernetes_engine/README.md)'

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
# Docker 설치 스크립트 다운로드 및 실행
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

docker login cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com

# Username: AccessKey ID 입력
# Password: Secret Access Key 입력

# 다음 명령어를 이용하여 Container Registry에 Image를 Push할 수 있습니다.
# docker tag 명령어를 이용하여 Image를 태깅 할 수 있습니다.

docker tag image:1 cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>
docker push cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>

#다음 명령어를 이용하여 Container Registry에서 Image를 Pull할 수 있습니다.

$ docker pull cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/<repository>/<image>:<tag>
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
REGISTRY_URL="cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com"

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
REGISTRY_URL="cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com"
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

## 부록 (Container Registry 연습)

### 애플리케이션 이미지 생성

```bash
# 작업 디렉토리 생성
mkdir sample-web-app
cd sample-web-app

# 간단한 HTML 파일 생성
cat > index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Sample Web App</title>
</head>
<body>
    <h1>Hello from Container Registry!</h1>
    <p>This is a sample web application running in a container.</p>
    <p>Version: 1.0.0</p>
</body>
</html>
EOF

# Dockerfile 생성
cat > Dockerfile << EOF
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
```

**&#128906; Docker 이미지 빌드**

```bash
# 이미지 빌드 (v1.0.0 태그)
docker build -t sample-web-app:v1.0.0 .

# 빌드된 이미지 확인
docker images
```

### 이미지 Container Registry에서 관리

**&#128906; 이미지 태그 지정 및 Push**

```bash
# Registry 엔드포인트에 맞게 이미지 태그 지정
docker tag sample-web-app:v1.0.0 cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v1.0.0

# 이미지를 Registry에 Push
docker push cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v1.0.0
```

**&#128906; 애플리케이션 수정**

```bash
# HTML 파일 수정 (버전 업데이트)
cat > index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Sample Web App v2</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f8ff; }
        h1 { color: #4CAF50; }
    </style>
</head>
<body>
    <h1>Hello from Container Registry v2!</h1>
    <p>This is an updated sample web application running in a container.</p>
    <p>Version: 2.0.0</p>
    <p>New features: Added CSS styling!</p>
</body>
</html>
EOF

# 새 버전 이미지 빌드
docker build -t sample-web-app:v2.0.0 .

# Registry에 태그 지정
docker tag sample-web-app:v2.0.0 cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0

# 새 버전 Push
docker push cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0

# latest 태그 생성
docker tag cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0 cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:latest

# latest Push
docker push cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:latest
```

**&#128906; 이미지 Pull 테스트**

```bash
# 로컬 이미지 삭제 (Pull 테스트를 위해)
docker rmi sample-web-app:v1.0.0 sample-web-app:v2.0.0

docker rmi cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v1.0.0

docker rmi cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0

# Registry에서 이미지 Pull
docker pull cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0

# 컨테이너 실행 테스트
docker run -d -p 8080:80 --name sample-web cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0

# 실행 확인
curl http://localhost:8080

# 컨테이너 중지 및 삭제
docker stop sample-web
docker rm sample-web
```

### Kubernetes와 Container Registry 연동

**&#128906; Kubernetes 클러스터 접속**

```bash
# Kubernetes 연결 체크
kubectl cluster-info
kubectl get nodes
```

**&#128906; Docker Registry Secret 생성**

```bash
# Registry 인증 정보를 Secret으로 생성
kubectl create secret docker-registry my-registry-secret \
  --docker-server=cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com \
  --docker-username=[your_scp_accss_key] \
  --docker-password=[your_scp_seret_key] \
  --docker-email=your@email.address

95a353f-db87-4d2e-b3d1-0a0486b7094f \
  --docker-email=revotty@gmail.com

# Secret 확인
kubectl get secrets
```

**&#128906; 애플리케이션 배포**

```bash
# Deployment YAML 생성
cat > sample-web-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-web-app
  labels:
    app: sample-web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-web-app
  template:
    metadata:
      labels:
        app: sample-web-app
    spec:
      imagePullSecrets:
      - name: my-registry-secret
      containers:
      - name: web-app
        image: cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/web-app:v2.0.0
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: sample-web-service
spec:
  selector:
    app: sample-web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30000
  type: NodePort
EOF

# 애플리케이션 배포
kubectl apply -f sample-web-deployment.yaml

# 배포 상태 확인
kubectl get deployments
kubectl get pods
kubectl get services
```

**&#128906; 애플리케이션 접속 테스트**

```bash
# NodePort를 통한 접속 (Bastion에서)
curl http://[KUBERNETES_NODE_IP]:30000

# 또는 포트 포워딩을 통한 접속
kubectl port-forward service/sample-web-service 8080:80 --address 0.0.0.0 &
curl http://localhost:8080
```

### 이미지 삭제 및 정리

#### 태그 삭제

**&#128906; Console에서 태그 삭제**

1. Registry → Repository → 태그 탭
2. 삭제할 태그 선택 (최대 50개)
3. "삭제" 클릭
4. 태그 이름 입력하여 확인

**주의사항:**

- 참조 중인 태그는 삭제 불가
- 잠긴 태그는 먼저 잠금 해제 필요

**&#128906; CLI에서 이미지 정리**

```bash
# 로컬 이미지 정리
docker system prune -a

# 사용하지 않는 이미지 삭제
docker rmi $(docker images -q --filter "dangling=true")
```

#### Repository 삭제

**&#128906; Repository 삭제 절차**

1. Repository에서 모든 이미지/태그 삭제
2. Repository 상세 페이지 → "Repository 삭제"
3. Repository 이름 입력하여 확인

#### Registry 삭제

**&#128906; Registry 삭제 절차**

**⚠️ 주의사항:**

- 연결된 모든 서비스 확인 및 해제
- 모든 데이터가 영구적으로 삭제됨
- 백업이 필요한 경우 사전 조치

1. 모든 Repository 및 이미지 삭제
2. Registry 상세 페이지 → "서비스 해지"
3. 확인 체크박스 선택
4. Registry 이름 입력하여 최종 확인

### 추가 활용 방안

#### CI/CD 파이프라인 연동

```bash
# GitHub Actions 예시 (.github/workflows/build.yml)
name: Build and Push to Registry

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Login to Container Registry
      run: |
        echo ${{ secrets.REGISTRY_PASSWORD }} | docker login \
          ${{ secrets.REGISTRY_URL }} \
          -u ${{ secrets.REGISTRY_USERNAME }} \
          --password-stdin

    - name: Build and Push
      run: |
        docker build -t ${{ secrets.REGISTRY_URL }}/sample-app/web-app:${{ github.sha }} .
        docker push ${{ secrets.REGISTRY_URL }}/sample-app/web-app:${{ github.sha }}
```

#### Helm Chart 관리

```bash
# Helm을 사용한 Chart Push/Pull
helm registry login cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com

# Chart 패키징 및 Push
helm package ./my-chart
helm push my-chart-0.1.0.tgz oci://cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/helm-charts

# Chart Pull 및 설치
helm pull oci://cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/helm-charts/my-chart --version 0.1.0
helm install my-release my-chart-0.1.0.tgz
```

## 실습 완료 후 정리

### 리소스 정리

```bash
# Kubernetes 리소스 정리
kubectl delete -f sample-web-deployment.yaml
kubectl delete secret my-registry-secret

# Docker 이미지 정리
docker system prune -a

# Container Registry 정리 (Console에서)
# 1. 모든 이미지 및 태그 삭제
# 2. Repository 삭제
# 3. Registry 삭제 (선택사항)
```

### Terraform 리소스 정리

```bash
# Terraform 리소스 삭제 (선택사항)
cd D:\scpv2\advance_cloudnative\container_registry\
terraform destroy --auto-approve
```

## 실습 요약

이 실습을 통해 다음을 학습했습니다:

1. **Container Registry 생성 및 구성**
   - Private/Public 엔드포인트 설정
   - 접근 제어 정책 구성

2. **Repository 관리**
   - Repository 생성 및 정책 설정
   - 이미지 취약점 스캔 활성화

3. **Docker CLI 활용**
   - Registry 로그인 및 인증
   - 이미지 빌드, 태그, Push/Pull

4. **이미지 수명 주기 관리**
   - 버전별 이미지 관리
   - 태그 자동 삭제 정책
   - 이미지 잠금 및 보안

5. **Kubernetes 연동**
   - Private Registry 연결
   - Secret 기반 이미지 Pull
   - 애플리케이션 배포 및 서비스 노출

6. **보안 관리**
   - 이미지 취약점 스캔
   - Pull 제한 정책
   - 접근 제어 관리

Container Registry는 컨테이너 기반 애플리케이션 개발 및 운영에 핵심적인 역할을 하며, 이를 통해 안전하고 효율적인 이미지 관리가 가능합니다.
