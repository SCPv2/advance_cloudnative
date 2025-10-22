# Kubernetes Cluster App 배포 및 관리

### 필수 '[Kubernetes Engine 생성 및 구성](https://github.com/SCPv2/advance_cloudnative/tree/main/kubernetes_engine)'

### 필수 '[Container Registry 구성 및 관리](http://github.com/SCPv2/advance_cloudnative/tree/main/container_registry)'

## Object Storage, Containter Registry 생성 (아래 차시 참고)

### 참고 '[고가용성을 위한 Object Storage 구성](https://github.com/SCPv2/advance_ha/tree/main/object_storage)'

### 참고 '[Container Registry 구성 및 관리](http://github.com/SCPv2/advance_cloudnative/tree/main/container_registry)'

## 실습 환경 배포

**&#128906; 사용자 환경 구성**  

(advance_cloudnative\container_app_deployment\env_setup.ps1)

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## Private DNS 와 VPC1 연결 (콘솔)

- Private DNS  >  VPC 연결 : VPC1

## Storage ACL 등록

**&#128906; Object Storage**

- 접근 제어 : 사용

- 서비스 자원 허용 : Kuberbetes Engine nodes(ske-cek8s-)

**&#128906; Container Registry**

- 프라이빗 엔드포인트 접근 제어 : 사용

- 프라이빗 접근 허용 리소스 : Kuberbeter Engine : cek8s

## Container App 배포 환경 구성(bastionvm110r)

- kubectl 다운로드 및 환경 설정 : [Kubernetes Engine 생성 및 구성](https://github.com/SCPv2/advance_cloudnative/tree/main/kubernetes_engine) 참조

- docker 설치 및 Container Registry 등록 : [Container Registry 구성 및 관리](http://github.com/SCPv2/advance_cloudnative/tree/main/container_registry) 참조

## Container App 배포

### 작업 디렉토리로 이동

```bash
cd /home/rocky/advance_cloudnative/container_app_deployment/k8s_app_deployment
```

### K8s 매니페스트 이미지 URL 확인

- 생성된 이미지들이 다음 매니페스트 파일에서 올바르게 참조되는지 확인:

```bash
# App deployment에서 사용하는 이미지
grep "image:" k8s-manifests/app-deployment.yaml
# 출력 예: image: cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/creative-energy-app:latest

# Web deployment에서 사용하는 이미지
grep "image:" k8s-manifests/web-deployment.yaml
# 출력 예: image: cecr-xxxxxx.scr.private.kr-west1.e.samsungsdscloud.com/ceweb/creative-energy-web:latest
```

### 네임스페이스 생성

- `creative-energy` 네임스페이스를 생성하여 모든 리소스를 격리

```bash
kubectl create namespace creative-energy

# 확인
kubectl get namespace creative-energy
```

### ConfigMap 생성

- `app-config`: 데이터베이스 호스트, 포트, 도메인 정보 저장

- `nginx-config`: Nginx 설정 파일 (nginx.conf, default.conf)

```bash
kubectl apply -f k8s-manifests/configmap.yaml

# 확인
kubectl get configmap -n creative-energy
kubectl describe configmap app-config -n creative-energy
```

### Master Config ConfigMap 생성

- `master-config`: Object Storage 연결 정보 및 인프라 설정 (setup-deployment.sh에서 자동 생성됨)

```bash
kubectl apply -f k8s-manifests/master-config-configmap.yaml

# 확인
kubectl get configmap master-config -n creative-energy
kubectl describe configmap master-config -n creative-energy
```

### Secret 생성

- `db-secret`: PostgreSQL 인증 정보 (cedbadmin/cedbadmin123!)

- `registry-credentials`: Container Registry 인증 정보

```bash
# 1. DB Secret 생성 (PostgreSQL 인증)
kubectl apply -f k8s-manifests/secret.yaml

# 2. Container Registry 로그인 및 Registry Secret 생성
cd scripts
chmod +x setup-registry-credentials.sh
./setup-registry-credentials.sh
cd ..

# 확인
kubectl get secret -n creative-energy
kubectl describe secret registry-credentials -n creative-energy
kubectl describe secret db-credentials -n creative-energy
```

### PVC (영구 스토리지) 생성

- `source-code-pvc` (2Gi): GitHub 소스코드 저장
- `upload-files-pvc` (10Gi): 사용자 업로드 파일
- `nginx-cache-pvc` (1Gi): Nginx 캐시

```bash
kubectl apply -f k8s-manifests/pvc.yaml

# 확인
kubectl get pvc -n creative-energy
kubectl describe pvc -n creative-energy
```

### PostgreSQL(DBaaS) 연결

- `db.private_domain_name:2866` PostgreSQL(DBaaS)를 클러스터 내부에서 `external-db-service`로 접근

```bash
kubectl apply -f k8s-manifests/external-db-service.yaml

# 확인
kubectl get service external-db-service -n creative-energy
```

### 내부 서비스 생성

- `web-service`: LoadBalancer 타입, 외부 접근용
- `app-service`: ClusterIP 타입, 내부 통신용

```bash
kubectl apply -f k8s-manifests/service.yaml

# 확인
kubectl get service -n creative-energy
```

### App 서버 배포

- Init Container: Git clone + npm install
- Main Container: Node.js 18, 포트 3000
- HPA: CPU 70%, Memory 80% 기준 자동 스케일링

```bash
kubectl apply -f k8s-manifests/app-deployment.yaml

# Pod 상태 확인
kubectl get pods -n creative-energy -l component=app-server

# 로그 확인
kubectl logs -f deployment/app-deployment -n creative-energy
```

### Web 서버 배포

- Init Container: Git clone(웹 리소스)
- Main Container: Nginx 1.24, 포트 8080
- 고정 2개 레플리카

```bash
kubectl apply -f k8s-manifests/web-deployment.yaml

# Pod 상태 확인
kubectl get pods -n creative-energy -l component=web-server

# 로그 확인
kubectl logs -f deployment/web-deployment -n creative-energy
```

### Ingress Controller 설치 및 도메인 라우팅

- **Ingress Controller**: L7 로드밸런서 (HTTP/HTTPS 라우팅)
- **RBAC 설정**: ServiceAccount, ClusterRole, ClusterRoleBinding
- **Admission Webhook**: Ingress 유효성 검증
- **도메인 라우팅**: 4개 호스트 지원

```bash
# Nginx Ingress Controller 설치
kubectl apply -f nginx-ingress-controller.yaml

# Ingress Controller Pod 상태 확인
kubectl get pods -n ingress-nginx

# Ingress Controller 서비스 확인
kubectl get service -n ingress-nginx
```

### Load Balancer 및 Firewall 확인

- Load Balancer Firewall 규칙

|Deployment|Firewall|Source|Destination|Service|Action|Direction|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Input|LB|0.0.0.0/0|10.1.2.0/24|TCP 80|Allow|Outbound|HTTP outbound|
|Input|LB|0.0.0.0/0|10.1.2.0/24|TCP 30000|Allow|Inbound|Loadbalancer to Node Port|

- K8s Securiy Group 규칙 확인

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Terrafom|K8sSG|Inbound|10.1.2.0/24|TCP 30000|LB to Node Port|

- LoadBalancer Public IP 연결 및 IP Public DNS 연결

```bash
# Ingress Controller의 외부 IP 확인
kubectl get service ingress-nginx-controller -n ingress-nginx

# 출력 예:
# NAME                       TYPE           EXTERNAL-IP     PORT(S)
# ingress-nginx-controller   LoadBalancer   203.xxx.xxx.xxx   80:30000/TCP,443:30443/TCP
```

### Ingress 규칙 확인

```bash
# Ingress 리소스 확인
kubectl get ingress -n creative-energy

# 상세 정보 확인
kubectl describe ingress ceweb-ingress -n creative-energy
```

### 배포 상태 확인

```bash
# 모든 리소스 확인
kubectl get all -n creative-energy

# Pod 상태 상세 확인
kubectl get pods -n creative-energy -o wide

# 배포 상태 모니터링
kubectl rollout status deployment/web-deployment -n creative-energy
kubectl rollout status deployment/app-deployment -n creative-energy

# 서비스 접근 정보 확인
kubectl get svc -n creative-energy
kubectl get ingress -n creative-energy

# HPA 상태
kubectl get hpa -n creative-energy

# 서비스 엔드포인트
kubectl get endpoints -n creative-energy

# Ingress 상태
kubectl get ingress -n creative-energy
```

### 애플리케이션 접속 테스트

- 직접 Service 접속 (LoadBalancer)

```bash
# LoadBalancer 외부 IP 확인
kubectl get service web-service -n creative-energy

# 웹 서비스 테스트 (Bastion에서)
curl http://<WEB_SERVICE_EXTERNAL_IP>/

# 헬스체크
curl http://<WEB_SERVICE_EXTERNAL_IP>/health
```

- Ingress를 통한 도메인 접속

```bash
# Ingress Controller 외부 IP 확인
INGRESS_IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: $INGRESS_IP"

# 도메인별 접속 테스트 (Host 헤더 사용)
curl -H "Host: creative-energy.net" http://$INGRESS_IP/
curl -H "Host: www.creative-energy.net" http://$INGRESS_IP/
curl -H "Host: cesvc.net" http://$INGRESS_IP/
curl -H "Host: www.cesvc.net" http://$INGRESS_IP/

# API 엔드포인트 테스트
curl -H "Host: creative-energy.net" http://$INGRESS_IP/health
```
