window.CE_CONFIG = {
  // API Gateway Invoke URL 
  //   예: apiBaseUrl: 'https://abcd1234.apigw.kr-east1.e.samsungsdscloud.com/prod'
  // 스테이지 루트까지만 적는다. 리소스 경로(/product)는 shop.html 이 붙인다.
  apiBaseUrl: 'https://abcd1234.apigw.kr-east1.e.samsungsdscloud.com/prod',
};

window.ceApi = async function ceApi(path, options = {}) {
  const base = window.CE_CONFIG.apiBaseUrl.replace(/\/+$/, '');
  const url = `${base}/${String(path).replace(/^\/+/, '')}`;
  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
    ...options,
  });
  if (!response.ok) {
    throw new Error(`API 호출 실패 (HTTP ${response.status})`);
  }
  return response.json();
};

window.ceConfigReady = function ceConfigReady() {
  return !window.CE_CONFIG.apiBaseUrl.startsWith('{{');
};