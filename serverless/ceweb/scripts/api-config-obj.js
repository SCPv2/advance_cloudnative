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
 * Creative Energy Object Storage API Configuration
 * Samsung Cloud Platform Object Storage 전용 API 엔드포인트 및 설정 관리
 */

// API 기본 설정
const API_CONFIG_OBJ = {
    // 환경별 API 기본 URL
    development: {
        baseURL: 'http://localhost:3000/api',
        timeout: 5000
    },
    production: {
        baseURL: '/api',
        timeout: 10000
    },
    
    // Object Storage 설정
    objectStorage: {
        publicEndpoint: 'https://object-store.kr-west1.e.samsungsdscloud.com',
        bucketName: 'ceweb',
        bucketString: null, // 동적으로 로드됨
        folders: {
            media: 'media/img',
            audition: 'files/audition'
        }
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

// Object Storage 전용 API 엔드포인트 정의
const API_ENDPOINTS_OBJ = {
    // 상품 관련 (Object Storage 버전)
    products: {
        list: '/objorders/products',
        detail: (id) => `/objorders/products/${id}`,
        inventory: (id) => `/objorders/products/${id}/inventory`
    },
    
    // 주문 관련 (Object Storage 버전)
    orders: {
        create: '/objorders/create',
        list: '/objorders/list',
        detail: (id) => `/objorders/${id}`
    },
    
    // 관리자 전용 API (Object Storage 버전)
    admin: {
        products: {
            list: '/objorders/admin/products',
            create: '/objorders/admin/products',
            update: (id) => `/objorders/admin/products/${id}`,
            delete: (id) => `/objorders/admin/products/${id}`
        },
        inventory: {
            list: '/objorders/admin/inventory',
            add: (id) => `/objorders/admin/inventory/${id}/add`,
            resetAll: '/objorders/admin/reset-inventory'
        },
        orders: {
            list: '/objorders/list',
            delete: (id) => `/objorders/admin/orders/${id}`
        }
    },
    
    // Samsung Cloud Platform Object Storage API
    objectStorage: {
        // 상품 이미지 업로드
        uploadProductImage: '/objupload/upload-product-image',
        
        // 오디션 파일 업로드
        uploadAuditionFile: '/objupload/upload-audition-file',
        
        // 파일 삭제 (type: 'product' | 'audition')
        deleteFile: (type, filename) => `/objupload/delete-file/${type}/${filename}`,
        
        // Object Storage 서비스 상태 확인
        status: '/objupload/status'
    },
    
    // 오디션 관련 (Object Storage 버전)
    audition: {
        upload: '/objaudition/upload',
        list: '/objaudition/files',
        download: (filename) => `/objaudition/download/${filename}`,
        delete: (filename) => `/objaudition/delete/${filename}`
    }
};

/**
 * Object Storage 퍼블릭 URL 생성
 * @param {string} type - 파일 타입 ('media' | 'audition')
 * @param {string} filename - 파일명
 * @returns {string} Object Storage 퍼블릭 URL
 */
function generateObjectStoragePublicUrl(type, filename) {
    const config = API_CONFIG_OBJ.objectStorage;
    const folderPath = type === 'media' ? config.folders.media : config.folders.audition;
    
    return `${config.publicEndpoint}/${config.bucketString}:${config.bucketName}/${folderPath}/${filename}`;
}

/**
 * 기존 상대경로를 Object Storage URL로 변환
 * @param {string} relativePath - 기존 상대경로 (예: ../media/img/bb_prod1.png)
 * @returns {string} Object Storage 퍼블릭 URL
 */
function convertToObjectStorageUrl(relativePath) {
    if (!relativePath) return '';
    
    // ../media/img/ 또는 ../../media/img/ 패턴 처리
    if (relativePath.includes('/media/img/')) {
        const filename = relativePath.split('/media/img/').pop();
        return generateObjectStoragePublicUrl('media', filename);
    }
    
    // /files/audition/ 패턴 처리
    if (relativePath.includes('/files/audition/')) {
        const filename = relativePath.split('/files/audition/').pop();
        return generateObjectStoragePublicUrl('audition', filename);
    }
    
    return relativePath; // 변환할 수 없는 경우 원본 반환
}

/**
 * API 요청을 위한 기본 함수 (Object Storage 버전)
 * @param {string} endpoint - API 엔드포인트
 * @param {object} options - 요청 옵션
 * @returns {Promise} 응답 데이터
 */
async function apiRequestObj(endpoint, options = {}) {
    const config = API_CONFIG_OBJ.current;
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
        console.log(`Object Storage API 요청: ${requestOptions.method} ${url}`);
        
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
        console.log('Object Storage API 응답:', data);
        
        return data;
        
    } catch (error) {
        console.error('Object Storage API 요청 실패:', error);
        
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
 * 상품 목록 조회 (Object Storage 버전)
 * @returns {Promise} 상품 목록 (Object Storage URL 포함)
 */
async function getProductsObj() {
    const response = await apiRequestObj(API_ENDPOINTS_OBJ.products.list);
    
    // 상품 이미지 경로를 Object Storage URL로 변환
    if (response.success && response.products) {
        response.products = response.products.map(product => ({
            ...product,
            image: convertToObjectStorageUrl(product.image)
        }));
    }
    
    return response;
}

/**
 * 상품 재고 정보 조회 (Object Storage 버전)
 * @param {number} productId - 상품 ID
 * @returns {Promise} 상품 재고 정보
 */
async function getProductInventoryObj(productId) {
    const response = await apiRequestObj(API_ENDPOINTS_OBJ.products.inventory(productId));
    
    // 상품 이미지 경로를 Object Storage URL로 변환
    if (response.success && response.product) {
        response.product.image = convertToObjectStorageUrl(response.product.image);
    }
    
    return response;
}

/**
 * 주문 생성 (Object Storage 버전)
 * @param {object} orderData - 주문 데이터
 * @returns {Promise} 주문 생성 결과
 */
async function createOrderObj(orderData) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.orders.create, {
        method: 'POST',
        body: JSON.stringify(orderData)
    });
}

// ===========================================
// 관리자 전용 API 함수들 (Object Storage 버전)
// ===========================================

/**
 * 관리자 - 상품 목록 조회 (Object Storage 버전)
 * @returns {Promise} 상품 목록
 */
async function getAdminProductsObj() {
    const response = await apiRequestObj(API_ENDPOINTS_OBJ.admin.products.list);
    
    // 상품 이미지 경로를 Object Storage URL로 변환
    if (response.success && response.products) {
        response.products = response.products.map(product => ({
            ...product,
            image: convertToObjectStorageUrl(product.image)
        }));
    }
    
    return response;
}

/**
 * 관리자 - 상품 등록 (Object Storage 버전)
 * @param {object} productData - 상품 데이터
 * @returns {Promise} 상품 등록 결과
 */
async function createAdminProductObj(productData) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.products.create, {
        method: 'POST',
        body: JSON.stringify(productData)
    });
}

/**
 * 관리자 - 상품 수정 (Object Storage 버전)
 * @param {number} productId - 상품 ID
 * @param {object} productData - 수정할 상품 데이터
 * @returns {Promise} 상품 수정 결과
 */
async function updateAdminProductObj(productId, productData) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.products.update(productId), {
        method: 'PUT',
        body: JSON.stringify(productData)
    });
}

/**
 * 관리자 - 상품 삭제 (Object Storage 버전)
 * @param {number} productId - 상품 ID
 * @returns {Promise} 상품 삭제 결과
 */
async function deleteAdminProductObj(productId) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.products.delete(productId), {
        method: 'DELETE'
    });
}

/**
 * 관리자 - 재고 목록 조회 (Object Storage 버전)
 * @returns {Promise} 재고 목록
 */
async function getAdminInventoryObj() {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.inventory.list);
}

/**
 * 관리자 - 재고 추가 (Object Storage 버전)
 * @param {number} productId - 상품 ID
 * @param {number} quantity - 추가할 재고 수량
 * @returns {Promise} 재고 추가 결과
 */
async function addAdminInventoryObj(productId, quantity) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.inventory.add(productId), {
        method: 'POST',
        body: JSON.stringify({ quantity })
    });
}

/**
 * 관리자 - 모든 재고 리셋 (Object Storage 버전)
 * @returns {Promise} 재고 리셋 결과
 */
async function resetAdminInventoryObj() {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.inventory.resetAll, {
        method: 'POST'
    });
}

/**
 * 관리자 - 주문 목록 조회 (Object Storage 버전)
 * @returns {Promise} 주문 목록
 */
async function getAdminOrdersObj() {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.orders.list);
}

/**
 * 관리자 - 주문 삭제 (Object Storage 버전)
 * @param {number} orderId - 주문 ID
 * @returns {Promise} 주문 삭제 결과
 */
async function deleteAdminOrderObj(orderId) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.admin.orders.delete(orderId), {
        method: 'DELETE'
    });
}

// ===========================================
// Object Storage 파일 관리 API 함수들
// ===========================================

/**
 * Object Storage - 상품 이미지 업로드
 * @param {File} file - 업로드할 이미지 파일
 * @returns {Promise} 업로드 결과 (Object Storage Public URL 포함)
 */
async function uploadProductImageToObjectStorage(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    return await apiRequestObj(API_ENDPOINTS_OBJ.objectStorage.uploadProductImage, {
        method: 'POST',
        body: formData,
        headers: {} // Content-Type을 명시적으로 설정하지 않음 (multipart/form-data 자동 설정)
    });
}

/**
 * Object Storage - 오디션 파일 업로드
 * @param {File} file - 업로드할 파일
 * @returns {Promise} 업로드 결과 (Object Storage Public URL 포함)
 */
async function uploadAuditionFileToObjectStorage(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    return await apiRequestObj(API_ENDPOINTS_OBJ.audition.upload, {
        method: 'POST',
        body: formData,
        headers: {}
    });
}

/**
 * Object Storage - 파일 삭제
 * @param {string} type - 파일 타입 ('product' | 'audition')
 * @param {string} filename - 삭제할 파일명
 * @returns {Promise} 삭제 결과
 */
async function deleteFileFromObjectStorage(type, filename) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.objectStorage.deleteFile(type, filename), {
        method: 'DELETE'
    });
}

/**
 * Object Storage - 오디션 파일 목록 조회
 * @returns {Promise} 오디션 파일 목록 (Object Storage URL 포함)
 */
async function getAuditionFilesObj() {
    const response = await apiRequestObj(API_ENDPOINTS_OBJ.audition.list);
    
    // 파일 다운로드 URL을 Object Storage URL로 변환
    if (response.success && response.files) {
        response.files = response.files.map(file => ({
            ...file,
            downloadUrl: generateObjectStoragePublicUrl('audition', file.filename)
        }));
    }
    
    return response;
}

/**
 * Object Storage - 오디션 파일 삭제
 * @param {string} filename - 삭제할 파일명
 * @returns {Promise} 삭제 결과
 */
async function deleteAuditionFileObj(filename) {
    return await apiRequestObj(API_ENDPOINTS_OBJ.audition.delete(filename), {
        method: 'DELETE'
    });
}

/**
 * Object Storage - 서비스 상태 확인
 * @returns {Promise} Object Storage 서비스 상태
 */
async function getObjectStorageStatus() {
    return await apiRequestObj(API_ENDPOINTS_OBJ.objectStorage.status);
}

/**
 * 서버 정보 조회 (Object Storage 버전용)
 * @returns {Promise} 서버 정보
 */
async function getServerInfoObj() {
    try {
        // Web Load Balancer 정보 (현재 응답 중인 웹서버)
        const webInfo = await fetch('/vm-info.json').then(r => r.json()).catch(() => ({}));
        
        // App Load Balancer 정보 (현재 응답 중인 앱서버)
        const appInfo = await apiRequestObj('/health').catch(() => ({}));
        
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
            objectStorage: {
                endpoint: API_CONFIG_OBJ.objectStorage.publicEndpoint,
                bucket: `${API_CONFIG_OBJ.objectStorage.bucketString}:${API_CONFIG_OBJ.objectStorage.bucketName}`,
                status: 'connected'
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
            objectStorage: {
                endpoint: API_CONFIG_OBJ.objectStorage.publicEndpoint,
                bucket: `${API_CONFIG_OBJ.objectStorage.bucketString}:${API_CONFIG_OBJ.objectStorage.bucketName}`,
                status: 'disconnected'
            },
            timestamp: new Date().toISOString()
        };
    }
}

// ===========================================
// Object Storage 동적 URL 생성 함수들
// ===========================================

/**
 * 버킷 문자열 동적 로드
 * @returns {Promise<string>} 버킷 문자열
 */
async function loadBucketString() {
    if (API_CONFIG_OBJ.objectStorage.bucketString) {
        return API_CONFIG_OBJ.objectStorage.bucketString;
    }
    
    try {
        // 서버에서 버킷 문자열 조회
        const response = await apiRequestObj('/config/bucket-string');
        if (response.success && response.bucketString) {
            API_CONFIG_OBJ.objectStorage.bucketString = response.bucketString;
            return response.bucketString;
        }
    } catch (error) {
        console.warn('버킷 문자열 서버 로드 실패, 기본값 사용:', error);
    }
    
    // 기본값 사용
    const defaultBucketString = 'thisneedstobereplaced1234';
    API_CONFIG_OBJ.objectStorage.bucketString = defaultBucketString;
    return defaultBucketString;
}

/**
 * Object Storage Public URL 동적 생성
 * @param {string} type - 파일 타입 ('media' | 'audition')
 * @param {string} filename - 파일명
 * @returns {Promise<string>} Object Storage Public URL
 */
async function generateObjectStorageUrl(type, filename) {
    const bucketString = await loadBucketString();
    const { publicEndpoint, bucketName, folders } = API_CONFIG_OBJ.objectStorage;
    
    let folder;
    switch (type) {
        case 'media':
            folder = folders.media;
            break;
        case 'audition':
            folder = folders.audition;
            break;
        default:
            folder = 'media/img';
    }
    
    return `${publicEndpoint}/${bucketString}:${bucketName}/${folder}/${filename}`;
}

/**
 * 미디어 파일 Object Storage URL 생성
 * @param {string} filename - 파일명 (예: 'logo_banner.png')
 * @returns {Promise<string>} Object Storage Public URL
 */
async function generateMediaUrl(filename) {
    return await generateObjectStorageUrl('media', filename);
}

/**
 * 오디션 파일 Object Storage URL 생성
 * @param {string} filename - 파일명
 * @returns {Promise<string>} Object Storage Public URL
 */
async function generateAuditionUrl(filename) {
    return await generateObjectStorageUrl('audition', filename);
}

/**
 * 상대 경로를 Object Storage URL로 변환
 * @param {string} relativePath - 상대 경로 (예: './media/img/logo.png', '../media/img/cloudy1.png')
 * @returns {Promise<string>} Object Storage Public URL
 */
async function convertRelativePathToObjectStorageUrl(relativePath) {
    if (!relativePath || relativePath.startsWith('http')) {
        return relativePath; // 이미 완전한 URL이거나 빈 값
    }
    
    // 상대 경로에서 파일명 추출
    const filename = relativePath.split('/').pop();
    
    // 경로 타입 판단
    if (relativePath.includes('/files/') || relativePath.includes('/audition/')) {
        return await generateAuditionUrl(filename);
    } else {
        return await generateMediaUrl(filename);
    }
}

/**
 * HTML 이미지 요소들의 src 속성을 Object Storage URL로 동적 변경
 * @param {string} selector - CSS 선택자 (기본값: 'img[src*="media"], img[src*="files"]')
 */
async function convertImageSrcToObjectStorage(selector = 'img[src*="media"], img[src*="files"]') {
    const images = document.querySelectorAll(selector);
    
    for (const img of images) {
        const originalSrc = img.getAttribute('src');
        if (originalSrc && !originalSrc.startsWith('http')) {
            try {
                const objectStorageUrl = await convertRelativePathToObjectStorageUrl(originalSrc);
                img.setAttribute('src', objectStorageUrl);
                img.setAttribute('data-original-src', originalSrc); // 원본 경로 보존
            } catch (error) {
                console.warn('이미지 URL 변환 실패:', originalSrc, error);
            }
        }
    }
}

/**
 * CSS background-image 속성을 Object Storage URL로 동적 변경
 * @param {string} selector - CSS 선택자
 */
async function convertBackgroundImageToObjectStorage(selector) {
    const elements = document.querySelectorAll(selector);
    
    for (const element of elements) {
        const style = window.getComputedStyle(element);
        const backgroundImage = style.backgroundImage;
        
        if (backgroundImage && backgroundImage !== 'none') {
            const urlMatch = backgroundImage.match(/url\(['"]?([^'"]*?)['"]?\)/);
            if (urlMatch && urlMatch[1] && !urlMatch[1].startsWith('http')) {
                try {
                    const objectStorageUrl = await convertRelativePathToObjectStorageUrl(urlMatch[1]);
                    element.style.backgroundImage = `url('${objectStorageUrl}')`;
                    element.setAttribute('data-original-bg', urlMatch[1]); // 원본 경로 보존
                } catch (error) {
                    console.warn('배경 이미지 URL 변환 실패:', urlMatch[1], error);
                }
            }
        }
    }
}

/**
 * 페이지 로드 시 모든 미디어 URL을 Object Storage URL로 변환
 */
async function initObjectStorageUrls() {
    console.log('Object Storage URL 변환 시작...');
    
    try {
        // 버킷 문자열 미리 로드
        await loadBucketString();
        
        // 이미지 src 속성 변환
        await convertImageSrcToObjectStorage();
        
        // CSS background-image 변환 (hero-slide 등)
        await convertBackgroundImageToObjectStorage('.hero-slide, .media-image, [style*="background-image"]');
        
        console.log('Object Storage URL 변환 완료');
    } catch (error) {
        console.error('Object Storage URL 변환 중 오류:', error);
    }
}

// 페이지 로드 시 자동 실행
if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initObjectStorageUrls);
    } else {
        initObjectStorageUrls();
    }
}

// 함수 별칭 (하위 호환성)
const getProducts = getProductsObj;
const getAdminProducts = getAdminProductsObj;

// 환경 정보 출력 (개발용)
console.log('Object Storage API 환경 설정:', {
    environment: API_CONFIG_OBJ.getCurrentEnv(),
    baseURL: API_CONFIG_OBJ.current.baseURL,
    timeout: API_CONFIG_OBJ.current.timeout,
    objectStorageEndpoint: API_CONFIG_OBJ.objectStorage.publicEndpoint,
    bucketInfo: `${API_CONFIG_OBJ.objectStorage.bucketString}:${API_CONFIG_OBJ.objectStorage.bucketName}`
});