# Samsung Cloud Platform API Gateway 구성 가이드

## Creative Energy Serverless Architecture 구현

---

## 📋 **목차**
1. [아키텍처 개요](#아키텍처-개요)
2. [사전 요구사항](#사전-요구사항)
3. [Cloud Functions 배포](#cloud-functions-배포)
4. [API Gateway 구성](#api-gateway-구성)
5. [테스트 및 검증](#테스트-및-검증)
6. [HTML 연동](#html-연동)

---

## 🏗️ **아키텍처 개요**

### **Serverless Architecture Flow:**
```
[Object Storage]     [API Gateway]        [Cloud Functions]    [Database]
정적 웹사이트    →    API 라우팅     →     비즈니스 로직   →   PostgreSQL
(HTML/CSS/JS)        (CORS, 인증)        (Node.js 20)        (db.creative-energy.net)
     ↑                    ↑                    ↑                    ↑
ceweb bucket        creative-energy-api    orders-get/post      cedb database
```

### **API 구조:**
```
Creative Energy API (단일 API)
└── /orders 리소스
    ├── GET /products → orders-get-function
    ├── GET /inventory?productId={id} → orders-get-function
    └── POST /create → orders-post-function
```

---

## 📋 **사전 요구사항**

### **1. Samsung Cloud Platform 권한**
- Cloud Functions 생성/관리 권한
- API Gateway 생성/관리 권한
- Object Storage 접근 권한

### **2. 준비된 파일**
```
D:\scpv2\advance_cloudnative\serverless\cloud_functions\
├── orders-get-function.js     # GET API 처리
├── orders-post-function.js    # POST API 처리
└── DEPLOYMENT_GUIDE.md        # Cloud Functions 배포 가이드
```

### **3. Database 정보**

NAT Gateway subnet13
VM생성 
dbvm131r 10.1.3.131

- **Host**: `db.creative-energy.net`
- **Port**: `2866`
- **Database**: `cedb`
- **User**: `cedbadmin`
- **Password**: `cedbadmin123!`

dbSG생성 

CF 엔드포인트 주소의 IP 2866 inbound
10.1.1.0/24 2866 inbound

IGW Firewall 
CF 엔드포인트 주소의 IP  10.1.3.131 2866 inbound

Public DNS : db.creative-energy.net dbvm Public IP



---

## ⚡ **Cloud Functions 배포**

### **Step 1: Orders GET Function 생성**

1. **콘솔 이동**
   - "모든 서비스 > Compute > Cloud Functions" 이동

2. **함수 생성 시작**
   - "함수 생성" 버튼 클릭

3. **기본 설정**
   - **함수명**: `creative-energy-orders-get` (3-64자, 소문자/숫자/하이픈)
   - **런타임**: Node.js 선택 (버전 20 선택)
   - **생성 방법**: 새로 생성

### 구성

- 일반 구성
  - 메모리 : 256MB
  - 제한시간 : 15초
  - 최소 작업 수 : 0
  - 최대 작업 수 : 3

- 환경 변수
  - `DB_USER`: `cedbadmin`
  - `DB_PASSWORD`: `cedbadmin123!`
  - `NODE_ENV`: `production`
  
- 함수 URL : 사용 (임시 사용)
  - 인증 유형 : None
  - 접근 제어 : 사용
  - 퍼블릭 접근 허용 IP : 내 PC Public IP

### 코드 업로드

- `orders-get-function.js` 파일 내용을 복사하여 붙여넣기




6. **트리거 설정** (선택사항)
   - API Gateway 연동은 나중에 설정

7. **태그 및 권한** (선택사항)
   - 필요시 태그 추가

8. **완료**
   - "완료" 버튼 클릭하여 함수 생성

### **Step 2: Orders POST Function 생성**

동일한 과정으로 POST 함수 생성:

1. **기본 설정**
   - **함수명**: `creative-energy-orders-post`
   - **런타임**: Node.js (버전 20)

2. **함수 구성**
   - **메모리 할당**: 512MB (트랜잭션 처리를 위해 더 큰 메모리)
   - **타임아웃**: 30초
   - **환경변수**: GET 함수와 동일

3. **코드 업로드**
   - `orders-post-function.js` 파일 내용을 인라인 에디터에 복사

4. **함수 생성 완료**

---

## API Gateway 구성

### API 생성

- API명 : `creative-energy-api`

### Orders 리소스 생성

- 리소스 이름 : `orders`

### Products 리소스 추가

- `/orders` 리소스 선택 후 하위 리소스 추가

- 리소스 경로**: `products`
- 전체 경로**: `/orders/products`

### Inventory 리소스 추가

- `/orders` 리소스 선택 후 하위 리소스 추가

- 리소스 경로: `inventory`
- 전체 경로: `/orders/inventory`

### Create 리소스 생성

- `/orders` 리소스 선택 후 하위 리소스 추가

- 리소스 경로: `create`
- 전체 경로: `/orders/create`

### GET /orders/products 메서드 생성

- `/orders/products` 리소스 선택

- HTTP 메서드 : `GET` 선택
- 통합 유형 : `Cloud Function`
- Cloud Function : `creative-energy-orders-get` 선택
- URL 쿼리 문자열 파라미터 : 선택하지 않음
- HTTP 요청 헤더 : 선택하지 않음

### GET /orders/inventory 메서드 생성

- `/orders/inventory` 리소스 선택

- HTTP 메서드 : `GET` 선택
- 통합 유형 : `Cloud Function`
- Cloud Function : `creative-energy-orders-get`
- URL 쿼리 문자열 파라미터 : 선택
  - 파라미터 이름: `productId`
  - 필수 : 선택하지 않음
- HTTP 요청 헤더 : 선택하지 않음

### POST /orders/create 메서드 생성

- `/orders/create` 리소스 선택

- HTTP 메서드 : `POST` 선택
- 통합 유형 : `Cloud Function`
- Cloud Function : `creative-energy-orders-post`
- URL 쿼리 문자열 파라미터 : 선택하지 않음
- HTTP 요청 헤더 : 선택하지 않음

### API 배포

- 스테이지 : New Stage
- 스테이지 명 : `prod`

### 스테이지

- CORS 설정 : 활성화
  - Access-Control-Allow-Methods : GET,POST 선택
  - Access-Control-Allow-Headers : `Content-Type`
  - Access-Control-Allow-Origin : `*`
  - Additional Settings : 선택 안함

- JWT 설정 : 활성화 안함
- IP Restriction 설정 : 활성화 선택

- 엔드포인트 URL 확인

```api-gateway-url
https://api-{random-id}.kr-west1.e.samsungsdscloud.com/{stage-name}

GET  https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/products
GET  https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/inventory?productId=123
POST https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/create
```

### 접근 제어

- 접근 제어명 : `ce-api-ip-restriction`

- Public 접근 허용 IP : 내 PC Public IP
- 연결할 스테이지 : prod

## 🧪 **테스트 및 검증**

### **1. API Gateway 테스트 콘솔**

각 메서드에 대해 API Gateway 콘솔에서 "테스트" 기능 사용:

#### **GET /orders/products 테스트**
```
HTTP Method: GET
Path: /orders/products
Headers: Content-Type: application/json
```

**예상 응답:**
```json
{
  "success": true,
  "products": [
    {
      "id": 1,
      "title": "BigBoys Album",
      "price": "25,000원",
      "stock_quantity": 100
    }
  ]
}
```

#### **POST /orders/create 테스트**
```
HTTP Method: POST
Path: /orders/create
Headers: Content-Type: application/json
Body: {
  "customerName": "테스트",
  "productId": 1,
  "quantity": 1
}
```

**예상 응답:**
```json
{
  "success": true,
  "message": "주문이 성공적으로 완료되었습니다.",
  "order": {
    "id": 123,
    "customerName": "테스트",
    "productTitle": "BigBoys Album",
    "quantity": 1,
    "totalPrice": 25000
  }
}
```

### **2. 외부 도구 테스트**

#### **curl을 사용한 테스트:**
```bash
# 상품 목록 조회
curl -X GET "https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/products" \
  -H "Content-Type: application/json"

# 주문 생성
curl -X POST "https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod/orders/create" \
  -H "Content-Type: application/json" \
  -d '{"customerName":"테스트","productId":1,"quantity":1}'
```

---

## 🔗 **HTML 연동**

### **api-config.js 업데이트**

`D:\scpv2\advance_cloudnative\serverless\ceweb\scripts\api-config.js` 파일을 수정:

```javascript
// Samsung Cloud Platform API Gateway Endpoint
const API_GATEWAY_URL = 'https://api-xxxxxx.kr-west1.e.samsungsdscloud.com/prod';

const API_CONFIG = {
    // Orders API
    PRODUCTS_LIST: `${API_GATEWAY_URL}/orders/products`,
    PRODUCT_INVENTORY: `${API_GATEWAY_URL}/orders/products`,  // /{productId}/inventory 추가 필요
    ORDER_CREATE: `${API_GATEWAY_URL}/orders/create`,

    // API 헬퍼 함수
    getProductInventoryUrl: function(productId) {
        return `${API_GATEWAY_URL}/orders/products/${productId}/inventory`;
    }
};

// 전역으로 내보내기
if (typeof window !== 'undefined') {
    window.API_CONFIG = API_CONFIG;
}
```

### **HTML 파일에서 API 사용**

#### **shop.html에서 상품 목록 로드:**
```javascript
// 상품 목록 조회
async function loadProducts() {
    try {
        const response = await fetch(API_CONFIG.PRODUCTS_LIST);
        const data = await response.json();

        if (data.success) {
            displayProducts(data.products);
        } else {
            console.error('Failed to load products:', data.message);
        }
    } catch (error) {
        console.error('API Error:', error);
    }
}
```

#### **order.html에서 주문 생성:**
```javascript
// 주문 생성
async function createOrder(customerName, productId, quantity) {
    try {
        const response = await fetch(API_CONFIG.ORDER_CREATE, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                customerName: customerName,
                productId: productId,
                quantity: quantity
            })
        });

        const data = await response.json();

        if (data.success) {
            alert('주문이 완료되었습니다!');
            return data.order;
        } else {
            alert('주문 실패: ' + data.message);
            return null;
        }
    } catch (error) {
        console.error('Order API Error:', error);
        alert('주문 처리 중 오류가 발생했습니다.');
        return null;
    }
}
```

---

## ⚠️ **주의사항 및 제한사항**

### **1. Samsung Cloud Platform 제약사항**
- Cloud Functions는 기본 Node.js 모듈만 사용 가능
- 외부 npm 패키지 사용 불가 (pg, axios 등)
- 데이터베이스 연결은 HTTP API 방식으로 구현

### **2. CORS 설정 필수**
- Object Storage 정적 웹사이트에서 API Gateway 호출 시 필요
- 모든 메서드에 OPTIONS 메서드 추가 필요

### **3. 데이터베이스 연결**
- 현재 코드는 HTTP API 방식으로 가정하여 작성됨
- 실제 PostgreSQL 연결 방법은 SCP Cloud Functions 지원 사양 확인 필요

### **4. 에러 처리**
- Cloud Functions에서 적절한 HTTP 상태 코드 반환 필요
- 프론트엔드에서 에러 상황에 대한 사용자 친화적 메시지 표시

---

## 📊 **모니터링 및 운영**

### **1. Cloud Functions 모니터링**
- 함수 실행 로그 확인
- 메모리 사용량 및 실행 시간 모니터링
- 에러율 및 성공률 추적

### **2. API Gateway 모니터링**
- API 호출 횟수 및 응답 시간
- 에러 상태 코드 분석
- 트래픽 패턴 분석

### **3. 비용 최적화**
- Cloud Functions 메모리 및 타임아웃 최적화
- API Gateway 캐싱 활용 검토
- 사용량 기반 알림 설정

---

## 🎯 **완료 체크리스트**

### **Cloud Functions**
- [ ] orders-get-function 배포 완료
- [ ] orders-post-function 배포 완료
- [ ] 환경변수 설정 완료
- [ ] 함수 테스트 완료

### **API Gateway**
- [ ] API 생성 완료
- [ ] 리소스 구조 설정 완료
- [ ] 메서드 및 통합 설정 완료
- [ ] CORS 설정 완료
- [ ] 스테이지 배포 완료

### **테스트**
- [ ] API Gateway 콘솔 테스트 완료
- [ ] 외부 도구(curl) 테스트 완료
- [ ] 프론트엔드 연동 테스트 완료

### **HTML 연동**
- [ ] api-config.js 업데이트 완료
- [ ] shop.html API 연동 완료
- [ ] order.html API 연동 완료

---

**🎉 Creative Energy Serverless Architecture 구축 완료!**

이제 Samsung Cloud Platform의 API Gateway와 Cloud Functions를 활용한 완전한 서버리스 아키텍처로 Creative Energy 웹사이트가 운영됩니다.