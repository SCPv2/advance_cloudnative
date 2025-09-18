# Cloud Functions Deployment Guide

## Samsung Cloud Platform Serverless Architecture

### 📋 사전 요구사항

1. **Samsung Cloud Platform 계정 및 권한**
   - Cloud Functions 생성 권한
   - API Gateway 생성 권한
   - Object Storage 접근 권한 (선택)

2. **Database Configuration**
   - Host: `db.creative-energy.net`
   - Port: `2866`
   - Database: `cedb`
   - User: `cedbadmin`
   - Password: `cedbadmin123!`

3. **파일 구조**
   ```
   D:\scpv2\advance_cloudnative\serverless\cloud_functions\
   ├── orders-function.js      # Orders API Cloud Function
   ├── audition-function.js    # Audition API Cloud Function (Optional)
   └── DEPLOYMENT_GUIDE.md     # 이 문서
   ```

---

## 🚀 Cloud Functions 배포 절차

### Step 1: Object Storage 버킷 준비

1. Samsung Cloud Platform 콘솔 접속
2. Storage > Object Storage 이동
3. `ceweb` 버킷 생성 또는 확인
4. 버킷에 폴더 구조 생성:
   ```
   ceweb/
   ├── media/
   │   └── files/
   │       └── audition/
   ```
5. Access Key/Secret Key 생성 및 저장

### Step 2: Cloud Functions 생성

#### Orders Function 생성

1. **콘솔에서 Cloud Functions 생성**
   - Function Name: `creative-energy-orders`
   - Runtime: Node.js 20
   - Memory: 512MB
   - Timeout: 30초

2. **환경변수 설정**
   ```
   DB_USER=cedbadmin
   DB_PASSWORD=cedbadmin123!
   ```

3. **코드 업로드**

   **Samsung Cloud Platform 방식:**
   - Node.js는 **인라인 에디터**에서 직접 코드 편집 지원
   - 콘솔에서 코드를 직접 입력하고 "저장" 버튼 클릭

   **사용할 코드:**
   ```javascript
   // orders-function.js 파일 내용을 복사하여 콘솔 에디터에 붙여넣기
   // 기본 Node.js 모듈만 사용 (https, querystring 등)
   // 외부 패키지(pg) 대신 HTTP API 방식으로 데이터베이스 연결
   ```

   **주의사항:**
   - 외부 npm 패키지(pg, @aws-sdk) 사용 불가
   - 기본 Node.js 모듈만 사용
   - 데이터베이스 연결은 HTTP API 방식으로 구현

#### Audition Function 생성 (Optional)

1. **콘솔에서 Cloud Functions 생성**
   - Function Name: `creative-energy-audition`
   - Runtime: Node.js 20
   - Memory: 1GB (파일 처리를 위해 더 큰 메모리)
   - Timeout: 60초

2. **환경변수 설정**
   ```
   DB_USER=cedbadmin
   DB_PASSWORD=cedbadmin123!
   S3_ENDPOINT=https://object-store.kr-west1.e.samsungsdscloud.com
   S3_ACCESS_KEY=your-access-key
   S3_SECRET_KEY=your-secret-key
   S3_BUCKET_NAME=ceweb
   ```

3. **코드 업로드**

   **Samsung Cloud Platform 방식:**
   - Node.js는 **인라인 에디터**에서 직접 코드 편집 지원
   - 콘솔에서 코드를 직접 입력하고 "저장" 버튼 클릭

   **사용할 코드:**
   ```javascript
   // audition-function.js 파일 내용을 복사하여 콘솔 에디터에 붙여넣기
   // Object Storage 연동 없이 파일 메타데이터만 관리
   // 기본 Node.js 모듈만 사용
   ```

   **주의사항:**
   - 외부 npm 패키지(@aws-sdk, pg) 사용 불가
   - Object Storage 연동은 별도 구현 필요
   - 현재는 파일 정보만 데이터베이스에 저장

---

## 🌐 API Gateway 설정

### Step 1: API 생성

1. Application > API Gateway 이동
2. "API 생성" 클릭
3. API 정보 입력:
   - API Name: `creative-energy-api`
   - Description: Creative Energy Serverless API

### Step 2: 리소스 및 메서드 설정

#### Orders API 리소스

1. **리소스 생성: `/orders`**
   - GET `/orders/products` → orders function
   - POST `/orders/create` → orders function
   - GET `/orders/list` → orders function
   - GET `/orders/customer/{customerName}` → orders function

2. **관리자 리소스: `/orders/admin`**
   - GET `/orders/admin/products` → orders function
   - POST `/orders/admin/products` → orders function
   - PUT `/orders/admin/products/{id}` → orders function
   - DELETE `/orders/admin/products/{id}` → orders function
   - POST `/orders/admin/reset-inventory` → orders function

#### Audition API 리소스 (Optional)

1. **리소스 생성: `/audition`**
   - POST `/audition/upload` → audition function
   - GET `/audition/files` → audition function
   - GET `/audition/download/{fileId}` → audition function
   - DELETE `/audition/delete/{fileId}` → audition function
   - GET `/audition/presigned-upload` → audition function

### Step 3: CORS 설정

각 메서드에 대해 CORS 설정:
```json
{
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
  "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
}
```

### Step 4: 배포

1. Stage 생성: `prod`
2. API 배포
3. Endpoint URL 확인 및 저장

---

## 📝 HTML 파일 업데이트

### API Endpoint 설정

생성된 API Gateway endpoint를 HTML 파일에 반영:

**예시 Endpoint:**
```
https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod
```

### api-config.js 수정

```javascript
// D:\scpv2\advance_cloudnative\serverless\ceweb\scripts\api-config.js

const API_GATEWAY_URL = 'https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod';

const API_CONFIG = {
    orders: `${API_GATEWAY_URL}/orders`,
    audition: `${API_GATEWAY_URL}/audition`  // Optional
};
```

---

## 🧪 테스트

### Orders API 테스트

```bash
# 상품 목록 조회
curl https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/products

# 주문 생성
curl -X POST https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/create \
  -H "Content-Type: application/json" \
  -d '{"customerName":"테스트","productId":1,"quantity":1}'
```

### Audition API 테스트 (Optional)

```bash
# 파일 목록 조회
curl https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod/audition/files

# Presigned URL 생성
curl "https://api-gateway-xxxxx.kr-west1.e.samsungsdscloud.com/prod/audition/presigned-upload?filename=test.pdf&contentType=application/pdf"
```

---

## ⚠️ 주의사항

1. **Database 접근**: Public DNS를 사용하므로 데이터베이스가 외부 접근 허용 설정 필요
2. **Object Storage**: Access Key/Secret Key는 환경변수로 안전하게 관리
3. **파일 크기 제한**: API Gateway 및 Cloud Functions의 페이로드 제한 확인
4. **콜드 스타트**: 첫 호출 시 지연 시간 발생 가능

---

## 📊 모니터링

- Cloud Functions 로그: 콘솔에서 실행 로그 확인
- API Gateway 메트릭: 호출 횟수, 에러율, 레이턴시 모니터링
- Object Storage: 버킷 사용량 및 요청 수 모니터링

---

## 🔧 트러블슈팅

### Database 연결 실패
- Security Group에서 Cloud Functions IP 범위 허용 확인
- Database Public Access 설정 확인

### Object Storage 접근 실패
- Access Key/Secret Key 유효성 확인
- Bucket 권한 설정 확인
- Endpoint URL 정확성 확인

### API Gateway 오류
- CORS 설정 확인
- Function 연동 설정 확인
- Stage 배포 상태 확인

---

## 🧪 CLI 코드 업로드 테스트 결과

### 테스트 환경
- **Function ID**: `7577fdd93b9349cd9e11e0299df5192d`
- **Function Name**: `creative-energy-orders-get`
- **Runtime**: Node.js 20
- **CLI Version**: Samsung Cloud Platform CLI

### 테스트한 접근 방식

#### 1. 직접 CLI 명령어 방식
```bash
scpcli scf cloud-function code set --cloud_function_id 7577fdd93b9349cd9e11e0299df5192d --content "코드내용"
```
**결과**: ✅ 짧은 코드 성공, ❌ 긴 코드 실패
**에러**: `argument of type 'NoneType' is not iterable`

#### 2. 파일 참조 방식
```bash
scpcli scf cloud-function code set --cloud_function_id 7577fdd93b9349cd9e11e0299df5192d --content @"파일경로"
```
**결과**: ❌ 실패

#### 3. 파이프 입력 방식
```bash
cat "파일경로" | scpcli scf cloud-function code set --cloud_function_id 7577fdd93b9349cd9e11e0299df5192d --content -
```
**결과**: ❌ 실패

#### 4. Bash 스크립트 변수 방식
```bash
CONTENT=$(cat "파일경로")
scpcli scf cloud-function code set --cloud_function_id 7577fdd93b9349cd9e11e0299df5192d --content "$CONTENT"
```
**결과**: ❌ 실패

### 발견된 CLI 제한사항

1. **코드 길이 제한**: 특정 길이를 초과하는 코드는 CLI로 업로드 불가
2. **파일 처리 문제**: 파일 참조나 파이프 입력을 제대로 처리하지 못함
3. **에러 메시지**: `argument of type 'NoneType' is not iterable` - CLI 내부 처리 문제

### 코드 구조 수정 사항

#### SCP Blueprint 형식 적용
- **기존**: `exports.handler = async (event, context) => {}`
- **수정**: `exports.handleRequest = async function (params) {}`

#### 매개변수 구조 변경
```javascript
// 기존 (AWS Lambda 형식)
const { httpMethod, path, pathParameters, body, queryStringParameters } = event;

// 수정 (SCP 형식)
const httpMethod = params.httpMethod || params.method || 'GET';
const path = params.path || params.resource || '/';
const pathParameters = params.pathParameters || {};
const body = params.body || '';
const queryStringParameters = params.queryStringParameters || {};
```

### 권장 배포 방법

#### ✅ 콘솔 사용 (권장)
1. SCP 웹 콘솔 접속
2. Cloud Functions > 함수 선택
3. 코드 탭에서 인라인 에디터 사용
4. orders-function.js 내용 복사/붙여넣기
5. 저장 및 배포

#### ✅ ZIP 파일 업로드
1. 코드를 ZIP으로 압축
2. 콘솔에서 파일 업로드 선택
3. ZIP 파일 업로드

#### ✅ 단계적 업로드
1. 기본 구조를 CLI로 업로드
2. 상세 기능은 콘솔에서 추가

### 검증 완료 사항

- ✅ Function ID 정상 접근
- ✅ 환경변수 설정 완료 (DB_USER, DB_PASSWORD)
- ✅ 네트워크 설정 완료 (Public endpoint)
- ✅ JavaScript 문법 검증 통과
- ✅ SCP Blueprint 형식 적용 완료

### 결론

**SCP CLI의 `code set` 명령어는 짧은 코드에 대해서만 안정적으로 동작하며, 복잡한 프로덕션 코드의 경우 SCP 웹 콘솔을 통한 업로드가 필요합니다.**