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
 * Creative Energy Server Info Component
 * Load Balancer 환경에서 현재 서빙 중인 Web/App 서버 정보 표시
 */

class ServerInfoComponent {
    constructor(containerId) {
        this.container = document.getElementById(containerId);
        this.serverInfo = {
            web: { hostname: 'unknown', ip: 'unknown', status: 'unknown' },
            app: { hostname: 'unknown', ip: 'unknown', status: 'unknown' }
        };
        this.updateInterval = null;
        this.isVisible = false;
        
        this.init();
    }

    init() {
        this.createServerInfoHTML();
        this.loadServerInfo();
        this.startAutoUpdate();
        this.setupEventListeners();
    }

    createServerInfoHTML() {
        if (!this.container) return;

        this.container.innerHTML = `
            <div class="server-info-wrapper">
                <div class="server-info-toggle" id="serverInfoToggle">
                    <span class="server-status-indicator"></span>
                    <span class="server-info-text">서버정보</span>
                </div>
                
                <div class="server-info-panel" id="serverInfoPanel">
                    <div class="server-info-header">
                        <h4>현재 서비스 서버</h4>
                        <button class="close-btn" id="serverInfoClose">×</button>
                    </div>
                    
                    <div class="server-info-content">
                        <div class="server-item">
                            <div class="server-label">Web Server</div>
                            <div class="server-details">
                                <div class="server-hostname" id="webHostname">unknown</div>
                                <div class="server-ip" id="webIp">unknown</div>
                                <div class="server-status" id="webStatus">unknown</div>
                            </div>
                        </div>
                        
                        <div class="server-item">
                            <div class="server-label">App Server</div>
                            <div class="server-details">
                                <div class="server-hostname" id="appHostname">unknown</div>
                                <div class="server-ip" id="appIp">unknown</div>
                                <div class="server-status" id="appStatus">unknown</div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="server-info-footer">
                        <small class="last-update" id="lastUpdate">마지막 업데이트: -</small>
                    </div>
                </div>
            </div>
        `;

        this.addServerInfoCSS();
    }

    addServerInfoCSS() {
        if (document.getElementById('server-info-css')) return;

        const style = document.createElement('style');
        style.id = 'server-info-css';
        style.textContent = `
            .server-info-wrapper {
                position: relative;
                display: inline-block;
                margin-right: 15px;
            }

            .server-info-toggle {
                display: flex;
                align-items: center;
                gap: 5px;
                padding: 5px 10px;
                background: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.3);
                border-radius: 15px;
                cursor: pointer;
                transition: all 0.3s ease;
                font-size: 0.8rem;
                color: white;
            }

            .server-info-toggle:hover {
                background: rgba(255, 255, 255, 0.2);
            }

            .server-status-indicator {
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: #28a745;
                display: inline-block;
                animation: pulse 2s infinite;
            }

            .server-status-indicator.warning {
                background: #ffc107;
            }

            .server-status-indicator.error {
                background: #dc3545;
            }

            @keyframes pulse {
                0% { opacity: 1; }
                50% { opacity: 0.5; }
                100% { opacity: 1; }
            }

            .server-info-panel {
                position: absolute;
                top: 100%;
                right: 0;
                background: white;
                border: 1px solid #ddd;
                border-radius: 10px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.2);
                width: 280px;
                z-index: 1000;
                display: none;
                margin-top: 5px;
            }

            .server-info-panel.show {
                display: block;
                animation: slideDown 0.3s ease;
            }

            @keyframes slideDown {
                from {
                    opacity: 0;
                    transform: translateY(-10px);
                }
                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }

            .server-info-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 15px;
                border-bottom: 1px solid #eee;
                background: #f8f9fa;
                border-radius: 10px 10px 0 0;
            }

            .server-info-header h4 {
                margin: 0;
                font-size: 1rem;
                color: #333;
            }

            .close-btn {
                background: none;
                border: none;
                font-size: 1.2rem;
                cursor: pointer;
                color: #666;
                width: 25px;
                height: 25px;
                display: flex;
                align-items: center;
                justify-content: center;
                border-radius: 50%;
                transition: background 0.2s;
            }

            .close-btn:hover {
                background: #e9ecef;
            }

            .server-info-content {
                padding: 15px;
            }

            .server-item {
                margin-bottom: 15px;
                padding: 10px;
                background: #f8f9fa;
                border-radius: 8px;
                border-left: 4px solid #007bff;
            }

            .server-item:last-child {
                margin-bottom: 0;
            }

            .server-label {
                font-weight: bold;
                color: #495057;
                margin-bottom: 5px;
                font-size: 0.9rem;
            }

            .server-details {
                font-size: 0.8rem;
            }

            .server-hostname {
                color: #007bff;
                font-weight: 600;
            }

            .server-ip {
                color: #6c757d;
                margin: 2px 0;
            }

            .server-status {
                display: inline-block;
                padding: 2px 6px;
                border-radius: 12px;
                font-size: 0.7rem;
                font-weight: bold;
                text-transform: uppercase;
            }

            .server-status.online {
                background: #d4edda;
                color: #155724;
            }

            .server-status.offline {
                background: #f8d7da;
                color: #721c24;
            }

            .server-status.unknown {
                background: #f8f9fa;
                color: #6c757d;
            }

            .server-info-footer {
                padding: 10px 15px;
                border-top: 1px solid #eee;
                background: #f8f9fa;
                border-radius: 0 0 10px 10px;
            }

            .last-update {
                color: #6c757d;
                font-size: 0.7rem;
            }

            /* 모바일 대응 */
            @media (max-width: 768px) {
                .server-info-panel {
                    width: 260px;
                    right: -50px;
                }
                
                .server-info-text {
                    display: none;
                }
            }
        `;
        document.head.appendChild(style);
    }

    setupEventListeners() {
        const toggle = document.getElementById('serverInfoToggle');
        const panel = document.getElementById('serverInfoPanel');
        const closeBtn = document.getElementById('serverInfoClose');

        if (toggle) {
            toggle.addEventListener('click', (e) => {
                e.stopPropagation();
                this.togglePanel();
            });
        }

        if (closeBtn) {
            closeBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.hidePanel();
            });
        }

        // 외부 클릭시 패널 닫기
        document.addEventListener('click', (e) => {
            if (panel && !panel.contains(e.target) && !toggle?.contains(e.target)) {
                this.hidePanel();
            }
        });
    }

    togglePanel() {
        const panel = document.getElementById('serverInfoPanel');
        if (panel) {
            if (this.isVisible) {
                this.hidePanel();
            } else {
                this.showPanel();
                this.loadServerInfo(); // 패널 열 때 최신 정보 로드
            }
        }
    }

    showPanel() {
        const panel = document.getElementById('serverInfoPanel');
        if (panel) {
            panel.classList.add('show');
            this.isVisible = true;
        }
    }

    hidePanel() {
        const panel = document.getElementById('serverInfoPanel');
        if (panel) {
            panel.classList.remove('show');
            this.isVisible = false;
        }
    }

    async loadServerInfo() {
        try {
            if (typeof getServerInfo === 'function') {
                this.serverInfo = await getServerInfo();
                this.updateDisplay();
            }
        } catch (error) {
            console.error('서버 정보 로드 실패:', error);
        }
    }

    updateDisplay() {
        // Web Server 정보 업데이트
        this.updateElement('webHostname', this.serverInfo.web.hostname);
        this.updateElement('webIp', this.serverInfo.web.ip);
        this.updateStatusElement('webStatus', this.serverInfo.web.status);

        // App Server 정보 업데이트
        this.updateElement('appHostname', this.serverInfo.app.hostname);
        this.updateElement('appIp', this.serverInfo.app.ip);
        this.updateStatusElement('appStatus', this.serverInfo.app.status);

        // 마지막 업데이트 시간
        this.updateElement('lastUpdate', `마지막 업데이트: ${new Date().toLocaleTimeString()}`);

        // 전체 상태 표시기 업데이트
        this.updateStatusIndicator();
    }

    updateElement(id, text) {
        const element = document.getElementById(id);
        if (element) {
            element.textContent = text;
        }
    }

    updateStatusElement(id, status) {
        const element = document.getElementById(id);
        if (element) {
            element.textContent = status;
            element.className = `server-status ${status}`;
        }
    }

    updateStatusIndicator() {
        const indicator = document.querySelector('.server-status-indicator');
        if (indicator) {
            const webOnline = this.serverInfo.web.status === 'online';
            const appOnline = this.serverInfo.app.status === 'online';
            
            indicator.className = 'server-status-indicator';
            
            if (webOnline && appOnline) {
                indicator.classList.add('online');
            } else if (webOnline || appOnline) {
                indicator.classList.add('warning');
            } else {
                indicator.classList.add('error');
            }
        }
    }

    startAutoUpdate() {
        // 30초마다 자동 업데이트
        this.updateInterval = setInterval(() => {
            this.loadServerInfo();
        }, 30000);
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
function initServerInfo(containerId) {
    return new ServerInfoComponent(containerId);
}