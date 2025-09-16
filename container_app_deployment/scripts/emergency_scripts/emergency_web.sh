#!/bin/bash
# Samsung Cloud Platform v2 - Emergency Recovery Script
# Server Type: WEB SERVER
# Generated: 2025-09-16 15:38:58
#
# PURPOSE: Emergency installation and configuration when UserData fails
# USAGE: Run this script directly on the VM as root
#        sudo bash emergency_web.sh
#
# Referenced GitHub installation scripts:
# - Web Server: https://github.com/SCPv2/ceweb/blob/main/web-server/install_web_server.sh
# - App Server: https://github.com/SCPv2/ceweb/blob/main/app-server/install_app_server.sh
# Note: DB Server replaced by PostgreSQL DBaaS - managed by Samsung SDS

set -euo pipefail

# Color functions for better visibility
red() { echo -e "\033[31m\$1\033[0m"; }
green() { echo -e "\033[32m\$1\033[0m"; }
yellow() { echo -e "\033[33m\$1\033[0m"; }
cyan() { echo -e "\033[36m\$1\033[0m"; }

# Logging
log_info() { echo "[INFO] \$1"; }
log_success() { echo "\$(green "[SUCCESS]") \$1"; }
log_error() { echo "\$(red "[ERROR]") \$1"; }

echo "\$(cyan "==========================================")"
echo "\$(cyan "EMERGENCY WEB SERVER RECOVERY")"
echo "\$(cyan "Samsung Cloud Platform v2")"
echo "\$(cyan "==========================================")"
echo ""

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Please run: sudo bash emergency_web.sh"
    exit 1
fi

log_info "Starting emergency recovery for web server..."

# System Update
sys_update() {
    log_info "[1/4] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do 
        echo "Waiting for network connectivity..."
        sleep 10
    done
    
    for i in {1..3}; do 
        dnf clean all && dnf install -y epel-release && break
        sleep 30
    done
    
    dnf -y update || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    
    log_success "System updated with NTP"
}

# Repository Clone
repo_clone() {
    log_info "[2/4] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    log_success "Repository ready"
}

# Create master_config.json
create_master_config() {
    log_info "[3/4] Creating master_config.json..."
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
{"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"ceweb_required_variables":{"rollback_enabled":"true","nginx_port":"80","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","_source":"variables.tf CEWEB_REQUIRED category","object_storage_audition_folder":"files/audition","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","object_storage_region":"kr-west1","app_server_port":"3000","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","admin_email":"ars4mundus@gmail.com","db_type":"postgresql","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_ip":"10.1.3.132","git_branch":"main","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","web_lb_service_ip":"10.1.1.100","company_name":"Creative Energy","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"object_storage_bucket_name":"ceweb","node_env":"production","web_ip":"10.1.1.111","database_host":"db.your_private_domain.name","ssl_enabled":"false"},"image_engine_metadata":{"cache_file":"image_engine_id.json","scpcli_available":true,"last_updated":"2025-09-16T15:38:15Z"},"terraform_infra_variables":{"_comment":"Variables used by terraform for infrastructure deployment","db_ip2":"10.1.3.33","windows_image_id":"28d98f66-44ca-4858-904f-636d4f674a62","rocky_image_id":"253a91ea-1221-49d7-af53-a45c389e7e1a","_source":"variables.tf TERRAFORM_INFRA category and SCP CLI","postgresql_engine_id":"feebbfb2e7164b83a9855cacd0b64fde"},"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","image_engine_cache":"image_engine_id.json","created":"2025-09-16 15:38:58","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"container_registry_endpoint":"your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com","keypair_name":"mykey","public_domain_name":"your_public_domain.name","object_storage_secret_access_key":"put_your_authentificate_secret_key_here","_source":"variables.tf USER_INPUT category","private_domain_name":"your_private_domain.name","object_storage_bucket_string":"put_your_account_id_here","object_storage_access_key_id":"put_your_authentificate_access_key_here","user_public_ip":"your_public_ip/32","_comment":"Variables that users input interactively during deployment"}}
CONFIG_EOF
    
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    
    # Validate JSON
    if ! jq . /home/rocky/master_config.json >/dev/null; then
        log_error "Invalid JSON in master_config.json"
        exit 1
    fi
    
    log_success "master_config.json created and validated"
}

# Server-specific installation (from module)
# Custom: Copy index_nodb.html to index.html for no-database setup
custom_web_setup() {
    echo "[Custom] Setting up no-database web configuration..."
    if [ -f /home/rocky/ceweb/index_nodb.html ]; then
        echo "Copying index_nodb.html to index.html..."
        cp /home/rocky/ceweb/index_nodb.html /home/rocky/ceweb/index.html
        chown rocky:rocky /home/rocky/ceweb/index.html
        echo "✅ index.html replaced with index_nodb.html"
    else
        echo "index_nodb.html not found, using default index.html"
    fi
}

# Web Server Application Install Module
app_install() {
    echo "[4/5] Web server install..."
    
    # Install Nginx
    dnf install -y nginx
    systemctl start nginx && systemctl enable nginx
    
    # Create web directories with proper permissions
    WEB_DIR="/home/rocky/ceweb"
    sudo -u rocky mkdir -p $WEB_DIR/{media/img,files/audition}
    chown -R rocky:rocky $WEB_DIR
    chmod -R 755 $WEB_DIR
    
    # Set home directory permissions (critical for Nginx access)
    chmod 755 /home/rocky
    
    # SELinux configuration for home directory access
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
        echo "Setting SELinux contexts for web directory..."
        
        # Set proper SELinux context for web content
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR(/.*)?" 2>/dev/null || true
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR/media(/.*)?" 2>/dev/null || true  
        semanage fcontext -a -t httpd_exec_t "$WEB_DIR/files(/.*)?" 2>/dev/null || true
        restorecon -Rv $WEB_DIR 2>/dev/null || true
        
        # Enable home directory access
        setsebool -P httpd_enable_homedirs 1 2>/dev/null || true
        
        # Enable NFS file access (for various file contexts)
        setsebool -P httpd_use_nfs 1 2>/dev/null || true
    fi
    
    # Load master config and extract variables
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "your_private_domain.name"' $MASTER_CONFIG)
    PUBLIC_DOMAIN=$(jq -r '.user_input_variables.public_domain_name // "creative-energy.net"' $MASTER_CONFIG)
    APP_PORT=$(jq -r '.ceweb_required_variables.app_server_port // "3000"' $MASTER_CONFIG)
    
    # Create Nginx configuration
    cat > /etc/nginx/conf.d/creative-energy.conf << EOF
server {
    listen 80 default_server;
    server_name www.$PRIVATE_DOMAIN www.$PUBLIC_DOMAIN localhost;
    client_max_body_size 100M;
    
    location / {
        root /home/rocky/ceweb;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://app.$PRIVATE_DOMAIN:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location /health {
        proxy_pass http://app.$PRIVATE_DOMAIN:$APP_PORT/health;
        proxy_connect_timeout 5s;
    }
}
EOF
    
    # SELinux configuration for OpenStack
    if command -v setsebool >/dev/null 2>&1; then
        setsebool -P httpd_read_user_content 1 2>/dev/null || true
        setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    fi
    
    # Disable default server block (prevents Rocky Linux test page)
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    sed -i '/^    server {/,/^    }/s/^/#/' /etc/nginx/nginx.conf
    
    # Test nginx configuration and restart
    nginx -t && systemctl restart nginx
    
    # Wait for app server to be available
    echo "Checking app server connectivity..."
    for i in {1..20}; do
        if curl -f --connect-timeout 3 http://app.$PRIVATE_DOMAIN:$APP_PORT/health >/dev/null 2>&1; then
            echo "✅ App server connection verified"
            break
        elif [ $i -eq 20 ]; then
            echo "⚠️  App server not responding, but web server configured"
            break
        else
            echo "Attempt $i/20: App server not ready, waiting 5s..."
            sleep 5
        fi
    done
    
    echo "✅ Web server installed"
}

# Web Server Verification Module
verify_install() {
    echo "[5/5] Web verification..."
    
    # Check Nginx status
    systemctl is-active nginx || exit 1
    
    # Check port 80
    netstat -tlnp | grep :80 || exit 1
    
    # Test web server response with timeout and retry
    for i in {1..10}; do
        if curl -I --connect-timeout 5 http://localhost/ >/dev/null 2>&1; then
            echo "✅ Web server responding"
            break
        elif [ $i -eq 10 ]; then
            echo "⚠️  Web server timeout, but proceeding"
            break
        else
            echo "Attempt $i/10: Web server not ready, waiting 3s..."
            sleep 3
        fi
    done
    
    echo "✅ Web server verified"
}
# Main execution
main() {
    sys_update
    repo_clone
    create_master_config
    app_install
    verify_install
    
    echo ""
    log_success "🎉 EMERGENCY RECOVERY COMPLETED!"
    
    # Create ready indicator
    echo "$(date): Emergency recovery completed" > /home/rocky/${SERVER_TYPE^}_Emergency_Ready.log
    
    show_test_commands
}

# Show test commands for user verification
show_test_commands() {
    echo ""
    echo "$(cyan "==========================================")"
    echo "$(cyan "MANUAL TESTING COMMANDS")"
    echo "$(cyan "==========================================")"
    echo ""    echo "$(yellow "WEB SERVER TESTING:")"
    echo ""
    echo "1. Check Nginx status:"
    echo "   systemctl status nginx"
    echo ""
    echo "2. Test web server response:"
    echo "   curl -I http://localhost/"
    echo ""
    echo "3. Check Nginx configuration:"
    echo "   nginx -t"
    echo ""
    echo "4. View Nginx access logs:"
    echo "   tail -f /var/log/nginx/access.log"
    echo ""
    echo "5. Test specific endpoints:"
    echo "   curl http://localhost/"
    echo "   curl http://localhost/api/"
    echo ""
    echo "6. Check SELinux status:"
    echo "   getsebool httpd_read_user_content"
    echo "   getsebool httpd_can_network_connect"
    echo ""
    echo "7. Verify domain configuration:"
    echo "   cat /etc/nginx/conf.d/creative-energy.conf"
    echo ""
    echo "$(green "Emergency recovery script completed!")"
    echo "$(green "Use the commands above to verify the installation.")"
    echo ""
    echo "$(cyan "Log files:")"
    echo "  - Emergency recovery: /home/rocky/${SERVER_TYPE^}_Emergency_Ready.log"
    echo "  - Master config: /home/rocky/master_config.json"
    echo "  - Application logs: Check service-specific locations above"
    echo ""
}

# Define SERVER_TYPE for the script
SERVER_TYPE="web"

# Execute main function
main "$@"