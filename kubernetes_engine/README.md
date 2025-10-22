# Kubernetes Engine 생성 및 구성

## 선행 실습

### 선택 '[과정 소개](https://github.com/SCPv2/advance_introduction/blob/main/README.md)'

- Key Pair, 인증키, DNS 등 사전 준비

### 선택 '[Terraform을 이용한 클라우드 자원 배포](https://github.com/SCPv2/advance_iac/blob/main/terraform/README.md)'

- Samsung Cloud Platform v2 기반 Terraform 학습

## 실습 환경 배포

**&#128906; 사용자 환경 구성 (\advance_cloudnative\kubernetes_engine\env_setup.ps1)**

**&#128906; Terraform 자원 배포 템플릿 실행**

```bash
terraform init
terraform validate
terraform plan

terraform apply --auto-approve
```

## Kubernetes Engine 생성

- 클러스터명 : `cek8s`

- 제어 영역 설정
  - Kubernetes 버전 : v1.31.8  # 뒤에 Kubernetes Client 버전과 동일해야 함.
  - 프라이빗 엔드포인트 접근 제어 : bastionVM110r
  - 퍼블릭 엔드포인트 접근/접근 제어 : 사용 안함
  - 제어 영역 로깅 : 선택
  
- 네트워크 설정
  - VPC: VPC1
  - Subnet : Subnet12
  - Security Group : K8sSG

- File Storage 설정 : cefs_

- 프라이빗 접근 허용 리소스 추가 : bastionvm110r

## 노드 풀 생성

- 노드 풀명 : `cenode`

- 노드 풀
  - 노드 서버 타입 : Standard-1 / s1v2m4
  - 노드 서버 OS : Ubuntu 22.04
  - 노드 서버 Block Storage : SSD / 13 Units
  - Keypair : mykey
  - 노드 풀 자동 확장/축소 : 미사용
  - 노드 수 : 2
  - 노드 자동 복구 : 미사용
  - 노드 풀 레이블 : 미사용
  - 노드 풀 테인트 : 미사용

## Security Group 설정

|Deployment|Security Group|Direction|Target Address/Remote SG|Service|Description|
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----|
|Add|bastionSG|Outbound|K8s API Server IP|TCP 6443|Outbound to K8s API Server|

## Kubernetes Client 설치

```bash
# kubectl v1.31.8 다운로드 : 콘솔에서 선택한 Kubernetes 버전과 일치 확인
curl -LO https://dl.k8s.io/release/v1.31.8/bin/linux/amd64/kubectl

# 실행 권한 부여
chmod +x kubectl

# 시스템 경로로 이동
sudo mv kubectl /usr/local/bin/

# 설치 확인
kubectl version --client

# AUTHKEY_TOKEN 값 생성
ACCESS_KEY=your_access_key
SECRET_KEY=your_secret_key
echo -n "$ACCESS_KEY:$SECRET_KEY" | base64 -w0


# 디렉토리 생성
sudo mkdir ~/.kube
sudo vi ~/.kube/config

# kubeconfig 파일 입력 후 저장
kubectl version

# 아래와 같이 출력 확인
# Client Version: v1.31.8
# Kustomize Version: v5.4.2
# Server Version: v1.31.8-ske.p2 에러가 발생할 경우 Kubernetes Engine Console에서 프라이빗 엔드포인트 접근 허용 리소스에 서버 등록 확인

# 클러스터 정보 확인
kubectl cluster-info

# 노드 목록 확인
kubectl get nodes
```
