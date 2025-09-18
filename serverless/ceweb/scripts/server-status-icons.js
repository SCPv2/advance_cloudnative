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
 * Creative Energy Server Status Icons Component
 * Load Balancer 환경에서 Web/App 서버 상태를 아이콘으로 표시
 */

class ServerStatusIcons {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.config = null;
        // Load Balancer 정보 제거됨
        this.servers = {};
        this.updateInterval = null;
        
        this.initializeConfig().then(() => {
            this.init();
        });
    }

    async initializeConfig() {
        try {
            // master-variables-loader.js 사용하여 설정 로드
            if (window.MasterVariablesLoader) {
                this.config = await window.MasterVariablesLoader.getAllConfig();
            } else {
                // fallback: master_config.json 직접 로드
                const response = await fetch('/web-server/master_config.json');
                const masterConfig = await response.json();
                this.config = {
                    privateDomain: masterConfig.infrastructure?.domain?.private_domain_name || 'cesvc.net',
                    webLbServiceIp: masterConfig.infrastructure?.load_balancer?.web_lb_service_ip || '10.1.1.100',
                    appLbServiceIp: masterConfig.infrastructure?.load_balancer?.app_lb_service_ip || '10.1.2.100',
                    webPrimaryIp: masterConfig.infrastructure?.servers?.web_primary_ip || '10.1.1.111',
                    webSecondaryIp: masterConfig.infrastructure?.servers?.web_secondary_ip || '10.1.1.112',
                    appPrimaryIp: masterConfig.infrastructure?.servers?.app_primary_ip || '10.1.2.121',
                    appSecondaryIp: masterConfig.infrastructure?.servers?.app_secondary_ip || '10.1.2.122'
                };
            }
        } catch (error) {
            console.warn('Failed to load configuration, using defaults:', error.message);
            this.config = {
                privateDomain: 'cesvc.net',
                webLbServiceIp: '10.1.1.100',
                appLbServiceIp: '10.1.2.100',
                webPrimaryIp: '10.1.1.111',
                webSecondaryIp: '10.1.1.112',
                appPrimaryIp: '10.1.2.121',
                appSecondaryIp: '10.1.2.122'
            };
        }

        // Load Balancer 정보 제거됨
        
        this.servers = {
            web: [
                { id: 'web1', name: 'Web-1', hostname: 'webvm111r', ip: this.config.webPrimaryIp, status: 'unknown' },
                { id: 'web2', name: 'Web-2', hostname: 'webvm112r', ip: this.config.webSecondaryIp, status: 'unknown' }
            ],
            app: [
                { id: 'app1', name: 'App-1', hostname: 'appvm121r', ip: this.config.appPrimaryIp, status: 'unknown' },
                { id: 'app2', name: 'App-2', hostname: 'appvm122r', ip: this.config.appSecondaryIp, status: 'unknown' }
            ]
        };
    }

    init() {
        this.createServerIconsHTML();
        this.loadServerStatus();
        this.startAutoUpdate();
    }

    createServerIconsHTML() {
        if (!this.container) return;

        this.container.innerHTML = `
            <div class="server-status-container">
                <!-- Web Servers -->
                <div class="server-group">
                    <div class="server-group-label">WEB</div>
                    <div class="server-icons-row">
                        ${this.servers.web.map(server => this.createServerIcon(server, 'web')).join('')}
                    </div>
                </div>
                
                <!-- App Servers -->
                <div class="server-group">
                    <div class="server-group-label">APP</div>
                    <div class="server-icons-row">
                        ${this.servers.app.map(server => this.createServerIcon(server, 'app')).join('')}
                    </div>
                </div>
                
                <!-- 상세 정보 툴팁 -->
                <div class="server-tooltip" id="serverTooltip">
                    <div class="tooltip-header">
                        <span class="tooltip-title" id="tooltipTitle">Server Info</span>
                    </div>
                    <div class="tooltip-content">
                        <div class="tooltip-row">
                            <span class="tooltip-label">호스트명:</span>
                            <span class="tooltip-value" id="tooltipHostname">Unknown</span>
                        </div>
                        <div class="tooltip-row">
                            <span class="tooltip-label">상태:</span>
                            <span class="tooltip-value" id="tooltipStatus">Unknown</span>
                        </div>
                        <div class="tooltip-row">
                            <span class="tooltip-label">IP:</span>
                            <span class="tooltip-value" id="tooltipIp">Unknown</span>
                        </div>
                        <div class="tooltip-row">
                            <span class="tooltip-label">응답시간:</span>
                            <span class="tooltip-value" id="tooltipResponseTime">-</span>
                        </div>
                    </div>
                </div>
            </div>
        `;

        this.addServerIconsCSS();
        this.setupEventListeners();
    }

    createServerIcon(server, type) {
        const iconSymbol = type === 'web' ? '🌐' : '⚙️';
        return `
            <div class="server-icon ${server.status}" 
                 id="${server.id}" 
                 data-server-id="${server.id}"
                 data-server-name="${server.name}"
                 data-server-type="${type}">
                <div class="server-icon-symbol">${iconSymbol}</div>
                <div class="server-icon-name">${server.name}</div>
                <div class="server-status-dot"></div>
            </div>
        `;
    }

    addServerIconsCSS() {
        if (document.getElementById('server-icons-css')) return;

        const style = document.createElement('style');
        style.id = 'server-icons-css';
        style.textContent = `
            .server-status-container {
                display: flex;
                align-items: center;
                gap: 12px;
                position: relative;
            }


            .server-group {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 4px;
            }

            .server-group-label {
                font-size: 0.7rem;
                color: rgba(255, 255, 255, 0.8);
                font-weight: bold;
                text-align: center;
                margin-bottom: 2px;
            }

            .server-icons-row {
                display: flex;
                gap: 6px;
            }

            .server-icon {
                position: relative;
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 8px;
                background: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.3s ease;
                min-width: 50px;
                backdrop-filter: blur(5px);
            }

            .server-icon:hover {
                background: rgba(255, 255, 255, 0.2);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            }

            .server-icon-symbol {
                font-size: 1.2rem;
                margin-bottom: 2px;
                filter: grayscale(100%);
                transition: filter 0.3s ease;
            }

            .server-icon.online .server-icon-symbol {
                filter: grayscale(0%);
            }

            .server-icon-name {
                font-size: 0.6rem;
                color: rgba(255, 255, 255, 0.9);
                font-weight: 500;
                text-align: center;
                line-height: 1;
            }

            .server-status-dot {
                position: absolute;
                top: 4px;
                right: 4px;
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: #6c757d;
                transition: all 0.3s ease;
                border: 1px solid rgba(255, 255, 255, 0.3);
            }

            .server-icon.online .server-status-dot {
                background: #28a745;
                box-shadow: 0 0 6px rgba(40, 167, 69, 0.6);
                animation: pulse-green 2s infinite;
            }

            .server-icon.offline .server-status-dot {
                background: #dc3545;
                box-shadow: 0 0 6px rgba(220, 53, 69, 0.6);
            }

            .server-icon.warning .server-status-dot {
                background: #ffc107;
                box-shadow: 0 0 6px rgba(255, 193, 7, 0.6);
            }

            .server-icon.unknown .server-status-dot {
                background: #6c757d;
            }

            @keyframes pulse-green {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.6; }
            }

            /* 툴팁 스타일 */
            .server-tooltip {
                position: absolute;
                top: 100%;
                left: 50%;
                transform: translateX(-50%);
                background: white;
                border: 1px solid #ddd;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.2);
                padding: 0;
                z-index: 1000;
                display: none;
                min-width: 200px;
                margin-top: 8px;
            }

            .server-tooltip.show {
                display: block;
                animation: tooltipFadeIn 0.2s ease;
            }

            @keyframes tooltipFadeIn {
                from {
                    opacity: 0;
                    transform: translateX(-50%) translateY(-5px);
                }
                to {
                    opacity: 1;
                    transform: translateX(-50%) translateY(0);
                }
            }

            .tooltip-header {
                background: #f8f9fa;
                padding: 10px 12px;
                border-bottom: 1px solid #e9ecef;
                border-radius: 8px 8px 0 0;
            }

            .tooltip-title {
                font-weight: bold;
                color: #495057;
                font-size: 0.9rem;
            }

            .tooltip-content {
                padding: 10px 12px;
            }

            .tooltip-row {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 6px;
                font-size: 0.8rem;
            }

            .tooltip-row:last-child {
                margin-bottom: 0;
            }

            .tooltip-label {
                color: #6c757d;
                font-weight: 500;
            }

            .tooltip-value {
                color: #495057;
                font-weight: bold;
            }

            .tooltip-value.online {
                color: #28a745;
            }

            .tooltip-value.offline {
                color: #dc3545;
            }

            .tooltip-value.warning {
                color: #ffc107;
            }

            /* 모바일 반응형 */
            @media (max-width: 768px) {
                .server-status-container {
                    gap: 10px;
                }
                
                .server-group-label {
                    font-size: 0.65rem;
                }
                
                .server-icon {
                    min-width: 40px;
                    padding: 6px;
                }
                
                .server-icon-symbol {
                    font-size: 1rem;
                }
                
                .server-icon-name {
                    font-size: 0.55rem;
                }
                
                .server-status-dot {
                    width: 6px;
                    height: 6px;
                    top: 2px;
                    right: 2px;
                }

                .server-tooltip {
                    left: 0;
                    transform: none;
                    margin-top: 5px;
                }
            }

            /* 작은 화면에서 툴팁 위치 조정 */
            @media (max-width: 480px) {
                .server-icons-row {
                    gap: 4px;
                }
                
                .server-icon {
                    min-width: 35px;
                    padding: 4px;
                }
            }
        `;
        document.head.appendChild(style);
    }

    setupEventListeners() {
        const tooltip = document.getElementById('serverTooltip');
        let tooltipTimeout;

        // 서버 아이콘 이벤트
        this.container.addEventListener('mouseenter', (e) => {
            const serverIcon = e.target.closest('.server-icon');
            if (serverIcon) {
                clearTimeout(tooltipTimeout);
                this.showTooltip(serverIcon);
            }
        }, true);

        this.container.addEventListener('mouseleave', (e) => {
            if (!this.container.contains(e.relatedTarget)) {
                tooltipTimeout = setTimeout(() => {
                    this.hideTooltip();
                }, 200);
            }
        }, true);

        // 툴팁 호버 유지
        if (tooltip) {
            tooltip.addEventListener('mouseenter', () => {
                clearTimeout(tooltipTimeout);
            });

            tooltip.addEventListener('mouseleave', () => {
                this.hideTooltip();
            });
        }

        // 외부 클릭시 툴팁 닫기
        document.addEventListener('click', (e) => {
            if (!this.container.contains(e.target)) {
                this.hideTooltip();
            }
        });
    }

    showTooltip(serverIcon) {
        const tooltip = document.getElementById('serverTooltip');
        if (!tooltip || !serverIcon) return;

        const serverId = serverIcon.dataset.serverId;
        const serverName = serverIcon.dataset.serverName;
        const serverType = serverIcon.dataset.serverType;
        
        // 서버 정보 찾기
        const serverInfo = this.findServerInfo(serverId, serverType);
        
        // 툴팁 내용 업데이트 (Load Balancer 환경)
        document.getElementById('tooltipTitle').textContent = serverName;
        document.getElementById('tooltipHostname').textContent = serverInfo.hostname || 'Unknown';
        
        const statusElement = document.getElementById('tooltipStatus');
        statusElement.textContent = serverInfo.status.toUpperCase();
        statusElement.className = `tooltip-value ${serverInfo.status}`;
        
        document.getElementById('tooltipIp').textContent = serverInfo.ip || 'Unknown';
        document.getElementById('tooltipResponseTime').textContent = serverInfo.responseTime || '-';

        tooltip.classList.add('show');
    }

    hideTooltip() {
        const tooltip = document.getElementById('serverTooltip');
        if (tooltip) {
            tooltip.classList.remove('show');
        }
    }

    findServerInfo(serverId, serverType) {
        const serverList = this.servers[serverType] || [];
        return serverList.find(s => s.id === serverId) || {
            status: 'unknown',
            ip: 'unknown',
            responseTime: '-'
        };
    }

    async loadServerStatus() {
        try {
            // 현재 Web 서버 정보 (실제 접속 중인 서버)
            const currentWebInfo = await this.getCurrentWebServerInfo();
            
            // Shop 페이지용 상품 API나 Health API로 현재 App 서버 정보 확인
            let currentAppInfo;
            try {
                // 상품 API에서 서버 정보 포함된 응답을 받아보기
                const productsResponse = await fetch('/api/orders/products', {
                    method: 'GET',
                    cache: 'no-cache',
                    signal: AbortSignal.timeout(5000)
                });
                if (productsResponse.ok) {
                    const data = await productsResponse.json();
                    if (data.server_info) {
                        currentAppInfo = {
                            status: 'online',
                            ip: data.server_info.ip,
                            hostname: data.server_info.hostname,
                            responseTime: '< 100ms',
                            vmNumber: data.server_info.vm_number || '1'
                        };
                    }
                }
            } catch (productsError) {
                console.log('상품 API 응답 없음, Health API 사용');
            }
            
            // 상품 API에서 응답이 없으면 Health API 사용
            if (!currentAppInfo) {
                currentAppInfo = await this.getCurrentAppServerInfo();
            }
            
            // 실제 VM 번호에 따라 서버 정보 배치
            const webVmNumber = parseInt(currentWebInfo.vmNumber) || 1;
            const appVmNumber = parseInt(currentAppInfo.vmNumber) || 1;
            
            // Load Balancer 환경: 모든 서버 초기화 (Load Balancer Pool 상태)
            this.servers.web.forEach((server, index) => {
                server.status = 'unknown';
                server.responseTime = '-';
                server.name = `Web-${index + 1}`;
            });
            
            this.servers.app.forEach((server, index) => {
                server.status = 'unknown';
                server.responseTime = '-';
                server.name = `App-${index + 1}`;
            });
            
            // 현재 Load Balancer에서 응답 중인 서버만 녹색으로 표시
            this.servers.web.forEach((server, index) => {
                if (server.hostname === currentWebInfo.hostname || index + 1 === webVmNumber) {
                    server.status = 'online';
                    server.responseTime = currentWebInfo.responseTime;
                    server.name = `Web-${index + 1} (현재)`;
                }
            });
            
            this.servers.app.forEach((server, index) => {
                if (server.hostname === currentAppInfo.hostname || index + 1 === appVmNumber) {
                    server.status = currentAppInfo.status;
                    server.responseTime = currentAppInfo.responseTime;
                    server.name = `App-${index + 1} (현재)`;
                }
            });
            
            this.updateDisplay();
            
            // 콘솔에 실제 서버 정보 출력 (디버깅용)
            console.log('현재 서빙 서버:', {
                web: `${currentWebInfo.hostname} (${currentWebInfo.ip}) - VM${webVmNumber}`,
                app: `${currentAppInfo.hostname} (${currentAppInfo.ip}) - VM${appVmNumber}`
            });
            
        } catch (error) {
            console.error('서버 상태 로드 실패:', error);
            // 오류 시 모든 서버를 offline으로 설정
            this.servers.web.forEach((server, index) => {
                server.status = 'offline';
                server.ip = 'unknown';
                server.responseTime = '-';
                server.name = `Web-${index + 1}`;
            });
            this.servers.app.forEach((server, index) => {
                server.status = 'offline';
                server.ip = 'unknown';
                server.responseTime = '-';
                server.name = `App-${index + 1}`;
            });
            this.updateDisplay();
        }
    }

    async getCurrentWebServerInfo() {
        const startTime = Date.now();
        try {
            // vm-info.json에서 현재 Web 서버 정보 가져오기
            const response = await fetch('/vm-info.json', {
                method: 'GET',
                cache: 'no-cache',
                signal: AbortSignal.timeout(5000)
            });
            
            const responseTime = Date.now() - startTime;
            
            if (response.ok) {
                const vmInfo = await response.json();
                return {
                    ip: vmInfo.ip_address || window.location.hostname,
                    hostname: vmInfo.hostname || 'unknown',
                    responseTime: responseTime + 'ms',
                    vmNumber: vmInfo.vm_number || '1'
                };
            } else {
                // vm-info.json이 없는 경우 기본 정보 사용
                return {
                    ip: window.location.hostname,
                    hostname: 'web-server',
                    responseTime: responseTime + 'ms',
                    vmNumber: '1'
                };
            }
        } catch (error) {
            const responseTime = Date.now() - startTime;
            return {
                ip: window.location.hostname,
                hostname: 'unknown',
                responseTime: responseTime + 'ms (error)',
                vmNumber: '1'
            };
        }
    }

    async getCurrentAppServerInfo() {
        const startTime = Date.now();
        try {
            // /api/health에서 현재 App 서버 정보 가져오기
            const response = await fetch('/api/health', {
                method: 'GET',
                cache: 'no-cache',
                signal: AbortSignal.timeout(5000)
            });
            
            const responseTime = Date.now() - startTime;
            
            if (response.ok) {
                const healthInfo = await response.json();
                return {
                    status: 'online',
                    ip: healthInfo.ip || healthInfo.hostname || 'unknown',
                    hostname: healthInfo.hostname || 'unknown',
                    responseTime: responseTime + 'ms',
                    vmNumber: healthInfo.vm_number || '1'
                };
            } else {
                return {
                    status: 'offline',
                    ip: 'unknown',
                    hostname: 'unknown', 
                    responseTime: responseTime + 'ms (error)',
                    vmNumber: '1'
                };
            }
        } catch (error) {
            const responseTime = Date.now() - startTime;
            return {
                status: 'offline',
                ip: 'unknown',
                hostname: 'unknown',
                responseTime: responseTime + 'ms (timeout)',
                vmNumber: '1'
            };
        }
    }

    async pingServer(endpoint) {
        const startTime = Date.now();
        try {
            const response = await fetch(endpoint, { 
                method: 'GET',
                cache: 'no-cache',
                signal: AbortSignal.timeout(5000)
            });
            
            const responseTime = Date.now() - startTime;
            const data = await response.json().catch(() => ({}));
            
            return {
                success: response.ok,
                responseTime,
                ip: data.ip_address || data.ip,
                hostname: data.hostname
            };
        } catch (error) {
            return {
                success: false,
                responseTime: Date.now() - startTime,
                error: error.message
            };
        }
    }

    updateDisplay() {
        // Web 서버 아이콘 업데이트
        this.servers.web.forEach(server => {
            const element = document.getElementById(server.id);
            if (element) {
                element.className = `server-icon ${server.status}`;
            }
        });

        // App 서버 아이콘 업데이트
        this.servers.app.forEach(server => {
            const element = document.getElementById(server.id);
            if (element) {
                element.className = `server-icon ${server.status}`;
            }
        });
    }

    startAutoUpdate() {
        // 15초마다 자동 업데이트
        this.updateInterval = setInterval(() => {
            this.loadServerStatus();
        }, 15000);
    }

    stopAutoUpdate() {
        if (this.updateInterval) {
            clearInterval(this.updateInterval);
            this.updateInterval = null;
        }
    }

    destroy() {
        this.stopAutoUpdate();
        if (this.container) {
            this.container.innerHTML = '';
        }
    }
}

// 전역 함수로 컴포넌트 초기화
function initServerStatusIcons(containerId) {
    return new ServerStatusIcons(containerId);
}