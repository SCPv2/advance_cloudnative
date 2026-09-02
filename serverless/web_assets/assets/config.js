window.CE_CONFIG = {
  // API Gateway Invoke URL 
  // 아래 {API Gateway Invoke URL}를 다음 형식으로 수정: apiBaseUrl: 'https://abcd1234.apigw.kr-east1.e.samsungsdscloud.com/product'
  apiBaseUrl: '{API Gateway Invoke URL}',
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
