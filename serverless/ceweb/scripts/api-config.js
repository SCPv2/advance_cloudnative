/*
==============================================================================
Copyright (c) 2025 Stan H. All rights reserved.

This software and its source code are the exclusive property of Stan H.

Use is strictly limited to 2025 SCPv2 Advance training and education only.
Any reproduction, modification, distribution, or other use beyond this scope is
strictly prohibited without prior written permission from the copyright holder.

Unauthorized use may lead to legal action under applicable law.

Contact: ars4mundus@gmail.com
==============================================================================
*/

/**
 * Creative Energy API Configuration
 * API 엔드포인트 및 설정 관리
 */

// API 기본 설정
const API_CONFIG = {
    // 환경별 API 기본 URL
    development: {
        baseURL: 'http://localhost:3000/api',
        timeout: 5000
    },
    production: {
        baseURL: '/api',
        timeout: 10000
    },
    
    // 현재 환경 (자동 감지)
    getCurrentEnv() {
        // 로컬 개발환경 감지
        if (window.location.hostname === 'localhost' || 
            window.location.hostname === '127.0.0.1' ||
            window.location.hostname.includes('192.168.') ||
            window.location.hostname.includes('10.0.') ||
            window.location.hostname.includes('172.16.')) {
            return 'development';
        }
        
        // 로드밸런서 환경에서 내부 IP 대역 체크
        const hostname = window.location.hostname;
        
        // 로드밸런서 환경의 내부 IP 대역들
        const internalNetworks = [
            '10.1.1.',    // Web Server 네트워크 (webvm111r, webvm112r)
            '10.1.2.',    // App Server 네트워크 (appvm121r, appvm122r)  
            '10.1.3.',    // DB Server 네트워크 (dbvm131r)
            '172.20.',    // Docker 내부 네트워크
            '172.30.',    // Kubernetes 내부 네트워크
            '10.'         // 기타 사설망 대역
        ];
        
        // 내부 IP 대역인 경우 development로 처리
        for (const network of internalNetworks) {
            if (hostname.startsWith(network)) {
                return 'development';
            }
        }
        
        return 'production';
    },
    
    // 현재 환경 설정 반환
    get current() {
        const env = this.getCurrentEnv();
        return this[env];
    }
};

// API 엔드포인트 정의
const API_ENDPOINTS = {
    // 상품 관련
    products: {
        list: '/orders/products',
        detail: (id) => `/orders/products/${id}`,
        inventory: (id) => `/orders/products/${id}/inventory`
    },
    
    // 주문 관련  
    orders: {
        create: '/orders/create',
        list: '/orders/list',
        detail: (id) => `/orders/${id}`
    },
    
    // 관리자 전용 API
    admin: {
        products: {
            list: '/orders/admin/products',
            create: '/orders/admin/products',
            update: (id) => `/orders/admin/products/${id}`,
            delete: (id) => `/orders/admin/products/${id}`
        },
        inventory: {
            list: '/orders/admin/inventory',
            add: (id) => `/orders/admin/inventory/${id}/add`,
            resetAll: '/orders/admin/reset-inventory'
        },
        orders: {
            list: '/orders/list',
            delete: (id) => `/orders/admin/orders/${id}`
        }
    },
    
    // Samsung Cloud Platform Object Storage API (S3 호환)
    s3: {
        // 상품 이미지 업로드
        uploadProductImage: '/s3/upload-product-image',
        
        // 오디션 파일 업로드
        uploadAuditionFile: '/s3/upload-audition-file',
        
        // 파일 삭제 (type: 'product' | 'audition')
        deleteFile: (type, filename) => `/s3/delete-file/${type}/${filename}`,
        
        // Presigned URL 생성 (type: 'product' | 'audition')
        presignedUrl: (type, filename, expiresIn = 3600) => `/s3/presigned-url/${type}/${filename}?expiresIn=${expiresIn}`,
        
        // CORS 설정
        setupCors: '/s3/setup-cors',
        
        // S3 서비스 상태 확인
        status: '/s3/status'
    }
};

/**
 * API 요청을 위한 기본 함수
 * @param {string} endpoint - API 엔드포인트
 * @param {object} options - 요청 옵션
 * @returns {Promise} 응답 데이터
 */
async function apiRequest(endpoint, options = {}) {
    const config = API_CONFIG.current;
    const url = config.baseURL + endpoint;
    
    const defaultOptions = {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json',
        },
        timeout: config.timeout
    };
    
    const requestOptions = { ...defaultOptions, ...options };
    
    try {
        console.log(`API 요청: ${requestOptions.method} ${url}`);
        
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), requestOptions.timeout);
        
        const response = await fetch(url, {
            ...requestOptions,
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        console.log('API 응답:', data);
        
        return data;
        
    } catch (error) {
        console.error('API 요청 실패:', error);
        
        // 네트워크 오류 처리
        if (error.name === 'AbortError') {
            throw new Error('요청 시간이 초과되었습니다.');
        }
        
        if (error.message.includes('Failed to fetch')) {
            throw new Error('서버에 연결할 수 없습니다. 네트워크 연결을 확인해주세요.');
        }
        
        throw error;
    }
}

/**
 * 상품 목록 조회
 * @returns {Promise} 상품 목록
 */
async function getProducts() {
    return await apiRequest(API_ENDPOINTS.products.list);
}

/**
 * 상품 재고 정보 조회
 * @param {number} productId - 상품 ID
 * @returns {Promise} 상품 재고 정보
 */
async function getProductInventory(productId) {
    return await apiRequest(API_ENDPOINTS.products.inventory(productId));
}

/**
 * 주문 생성
 * @param {object} orderData - 주문 데이터
 * @returns {Promise} 주문 생성 결과
 */
async function createOrder(orderData) {
    return await apiRequest(API_ENDPOINTS.orders.create, {
        method: 'POST',
        body: JSON.stringify(orderData)
    });
}

// ===========================================
// 관리자 전용 API 함수들
// ===========================================

/**
 * 관리자 - 상품 목록 조회
 * @returns {Promise} 상품 목록
 */
async function getAdminProducts() {
    return await apiRequest('/orders/admin/products');
}

/**
 * 관리자 - 상품 등록
 * @param {object} productData - 상품 데이터
 * @returns {Promise} 상품 등록 결과
 */
async function createAdminProduct(productData) {
    return await apiRequest('/orders/admin/products', {
        method: 'POST',
        body: JSON.stringify(productData)
    });
}

/**
 * 관리자 - 상품 수정
 * @param {number} productId - 상품 ID
 * @param {object} productData - 수정할 상품 데이터
 * @returns {Promise} 상품 수정 결과
 */
async function updateAdminProduct(productId, productData) {
    return await apiRequest(`/orders/admin/products/${productId}`, {
        method: 'PUT',
        body: JSON.stringify(productData)
    });
}

/**
 * 관리자 - 상품 삭제
 * @param {number} productId - 상품 ID
 * @returns {Promise} 상품 삭제 결과
 */
async function deleteAdminProduct(productId) {
    return await apiRequest(`/orders/admin/products/${productId}`, {
        method: 'DELETE'
    });
}

/**
 * 관리자 - 재고 목록 조회
 * @returns {Promise} 재고 목록
 */
async function getAdminInventory() {
    return await apiRequest('/orders/admin/inventory');
}

/**
 * 관리자 - 재고 추가
 * @param {number} productId - 상품 ID
 * @param {number} quantity - 추가할 재고 수량
 * @returns {Promise} 재고 추가 결과
 */
async function addAdminInventory(productId, quantity) {
    return await apiRequest(`/orders/admin/inventory/${productId}/add`, {
        method: 'POST',
        body: JSON.stringify({ quantity })
    });
}

/**
 * 관리자 - 모든 재고 리셋
 * @returns {Promise} 재고 리셋 결과
 */
async function resetAdminInventory() {
    return await apiRequest('/orders/admin/reset-inventory', {
        method: 'POST'
    });
}

/**
 * 관리자 - 주문 목록 조회 (일반 주문 목록과 동일)
 * @returns {Promise} 주문 목록
 */
async function getAdminOrders() {
    return await apiRequest('/orders/list');
}

/**
 * 관리자 - 주문 삭제
 * @param {number} orderId - 주문 ID
 * @returns {Promise} 주문 삭제 결과
 */
async function deleteAdminOrder(orderId) {
    return await apiRequest(`/orders/admin/orders/${orderId}`, {
        method: 'DELETE'
    });
}

/**
 * 서버 정보 조회 (Load Balancer 환경용)
 * @returns {Promise} 서버 정보
 */
async function getServerInfo() {
    try {
        // Web Load Balancer 정보 (현재 응답 중인 웹서버)
        const webInfo = await fetch('/vm-info.json').then(r => r.json()).catch(() => ({}));
        
        // App Load Balancer 정보 (현재 응답 중인 앱서버)
        const appInfo = await apiRequest('/health').catch(() => ({}));
        
        return {
            loadBalancer: {
                web: 'www.your_private_domain_name.net (10.1.1.100)',
                app: 'app.your_private_domain_name.net (10.1.2.100)',
                policy: 'Round Robin'
            },
            currentServing: {
                web: {
                    hostname: webInfo.hostname || 'unknown',
                    ip: webInfo.ip_address || 'unknown',
                    vm_number: webInfo.vm_number || '1',
                    status: 'online'
                },
                app: {
                    hostname: appInfo.hostname || 'unknown',
                    ip: appInfo.ip || 'unknown',
                    vm_number: appInfo.vm_number || '1',
                    status: appInfo.success ? 'online' : 'offline'
                }
            },
            architecture: {
                webServers: ['webvm111r (10.1.1.111)', 'webvm112r (10.1.1.112)'],
                appServers: ['appvm121r (10.1.2.121)', 'appvm122r (10.1.2.122)']
            },
            timestamp: new Date().toISOString()
        };
    } catch (error) {
        console.error('서버 정보 조회 실패:', error);
        return {
            loadBalancer: {
                web: 'www.your_private_domain_name.net (10.1.1.100)',
                app: 'app.your_private_domain_name.net (10.1.2.100)',
                status: 'error'
            },
            currentServing: {
                web: { hostname: 'unknown', ip: 'unknown', status: 'unknown' },
                app: { hostname: 'unknown', ip: 'unknown', status: 'unknown' }
            },
            timestamp: new Date().toISOString()
        };
    }
}

/**
 * S3 - 상품 이미지 업로드 (Samsung Cloud Platform Object Storage)
 * @param {File} file - 업로드할 이미지 파일
 * @returns {Promise} 업로드 결과 (S3 Public URL 포함)
 */
async function uploadProductImageToS3(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    return await apiRequest(API_ENDPOINTS.s3.uploadProductImage, {
        method: 'POST',
        body: formData,
        // Content-Type을 명시적으로 설정하지 않음 (multipart/form-data 자동 설정)
        headers: {} 
    });
}

/**
 * S3 - 오디션 파일 업로드 (Samsung Cloud Platform Object Storage)
 * @param {File} file - 업로드할 파일
 * @returns {Promise} 업로드 결과 (S3 Public URL 포함)
 */
async function uploadAuditionFileToS3(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    return await apiRequest(API_ENDPOINTS.s3.uploadAuditionFile, {
        method: 'POST',
        body: formData,
        headers: {}
    });
}

/**
 * S3 - 파일 삭제 (Samsung Cloud Platform Object Storage)
 * @param {string} type - 파일 타입 ('product' | 'audition')
 * @param {string} filename - 삭제할 파일명
 * @returns {Promise} 삭제 결과
 */
async function deleteFileFromS3(type, filename) {
    return await apiRequest(API_ENDPOINTS.s3.deleteFile(type, filename), {
        method: 'DELETE'
    });
}

/**
 * S3 - CORS 설정 (Samsung Cloud Platform Object Storage)
 * @returns {Promise} CORS 설정 결과
 */
async function setupS3CORS() {
    return await apiRequest(API_ENDPOINTS.s3.setupCors, {
        method: 'POST'
    });
}

/**
 * S3 - Presigned URL 생성 (Samsung Cloud Platform Object Storage)
 * @param {string} type - 파일 타입 ('product' | 'audition')
 * @param {string} filename - 파일명
 * @param {number} expiresIn - 만료 시간 (초, 기본: 3600)
 * @returns {Promise} Presigned URL 생성 결과
 */
async function getS3PresignedUrl(type, filename, expiresIn = 3600) {
    return await apiRequest(API_ENDPOINTS.s3.presignedUrl(type, filename, expiresIn));
}

/**
 * S3 - 서비스 상태 확인 (Samsung Cloud Platform Object Storage)
 * @returns {Promise} S3 서비스 상태
 */
async function getS3Status() {
    return await apiRequest(API_ENDPOINTS.s3.status);
}

// 환경 정보 출력 (개발용)
console.log('API 환경 설정:', {
    environment: API_CONFIG.getCurrentEnv(),
    baseURL: API_CONFIG.current.baseURL,
    timeout: API_CONFIG.current.timeout
});