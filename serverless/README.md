# Serverless Computing 구현

## 실행 환경 요구사항

### 필수 시스템 환경

- **운영체제**: Windows 10/11 또는 Windows Server 2019/2022
- **PowerShell 버전**: 7.6 이상 필수

  ```powershell
  # PowerShell 버전 확인
  $PSVersionTable.PSVersion
  ```

- **실습 파일** 다운로드

  ```powershell
  cd c:\scpv2lab\
  git clone https://github.com/SCPv2/advance_cloudnative.git
  ```

### 필수 도구 설치

- **AWS CLI 설치**
  Object Storage 사용자 가이드의 [Amazon S3 활용 가이드](https://docs.e.samsungsdscloud.com/userguide/storage/object_storage/overview/amazons3/)  
  [AWS CLI](https://awscli.amazonaws.com/AWSCLIV2.msi)

- AWS CLI 환경 설정
  ```powershell
  aws configure
  AWS Access Key ID [None]: 인증키 Access Key 입력
  AWS Secret Access Key [None]: 인증키 Secret Key 입력
  Default region name [None]: kr-east1
  Default output format [None]:
  ```

## Object Storage에 Web Assets 업로드

- kr-east1 로 리전 지정

- Object Storage 생성
  - 버킷명  : `ceweb`

- 버킷에 정적 웹 콘텐츠 업로드
  ```powershell
  cd C:\scpv2lab\advance_cloudnative\serverless\web_assets
  ```
  ```powershell  
  # [Public Endpoint] : Object Storage의 Public Endpoint 주소를 확인 후 바꿔서 입력
  aws s3 cp . s3://cewebdr/ --recursive --endpoint-url [Public Endpoint] --acl public-read
  ```

## Cloud Functions 생성

- kr-east1 지정
  
- Function 생성
  - Function 명 : `ceweb-prod`
  - Runtime : 새로 작성
  - Runtime & Version : Node.js 24

- 코드 업로드
  ```powershell
  cd C:\scpv2lab\advance_cloudnative\serverless
  
  # cloudfunctions_id는 만들어 놓은 Cloud Functions의 자원 ID를 입력
  $scp = "C:\scpv2lab\scp-cli.exe"; $fid = "cloudfunctions_id"; $rg = "kr-east1"
  
  #
  $code = Get-Content "cf_nodejs24_embedded.js" -Raw; & $scp --scp-region $rg scf cloud-function code set --cloud_function_id $fid --content $code
  ```

- 환경 변수 설정
  [Account ID로 입력]은 Account ID로 대체(입력 예시: 89097aaa09dddd96affffadeddddac29:cewebdr)

  |이름|값|비고|  
  |--|--|--|  
  |OBJECT_STORAGE_PROTOCOL|https://||  
  |OBJECT_STORAGE_HOST|object-store.kr-east1.e.samsungsdscloud.com||  
  |OBJECT_STORAGE_BUCKET|[Account ID]:cewebdr|입력 예시 89097aaa09dddd96affffadeddddac29:cewebdr|  
  |PRODUCTS_KEY|data/products.json||  
  |INVENTORY_KEY|data/inventory.json||  
  |ALLOW_ORIGIN|*||

## API Gateway 생성

- kr-east1 지정
  
- API 생성
  - API명: `cewebdrapi`
  - API 생성 방법: 새로 작성
  - API 엔드포인트 유형: Region

- 리소스 생성
  - 리소스명 : `product`
  - 리소스 경로 : `/`

- 메서드 생성
  - 메서드 유형 : `GET`
  - 통합 유형 : `Cloud Function`
  - 엔드포인트 : `ceweb-prod`

-API 배포
  - 스테이지명 : `New Stage`
  - 신규 스테이지명 : `product`

- CORS 설정
  - 활성화 : 체크
  - Access-Control-Allow-Methods : GET
  - Access-Control-Allow-Headers : Content-Type,Authorization
  - Access-Control-Allow-Origin : *

- JWT 설정 : 비활성화 

-접근 제어
  - 접근 제어명: `ceweb-test`
  - Public 접근 허용 IP : 실습자 PC의 Public IP
  - 연결할 스테이지 : `product`

## API Invoke URL 구성 및 수정

- config.js 수정(\assets\config.js)
  ```powershell
  edit C:\scpv2lab\advance_cloudnative\serverless\web_assets\assets\config.js
  ```
  ```js
  window.CE_CONFIG = {
    // API Gateway Invoke URL 
    //   아래 {API Gateway Invoke URL}를 다음 형식으로 수정: apiBaseUrl: 'https://abcd1234.apigw.kr-east1.e.samsungsdscloud.com/prod'
    apiBaseUrl: '{API Gateway Invoke URL}',
  };
  (후략)
  ```
- config.js 파일을 버킷에 업로드
  ```powershell
  # config.js 저장 디렉토리에서 실행
  aws s3 cp C:\scpv2lab\advance_cloudnative\serverless\web_assets\assets\config.js s3://cewebdr/assets/config.js --endpoint-url https://object-store.kr-east1.e.samsungsdscloud.com --acl public-read
  ```
