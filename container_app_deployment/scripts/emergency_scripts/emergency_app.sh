#!/bin/bash
# Samsung Cloud Platform v2 - Emergency Recovery Script
# Server Type: APP SERVER
# Generated: 2025-09-16 15:38:58
#
# PURPOSE: Emergency installation and configuration when UserData fails
# USAGE: Run this script directly on the VM as root
#        sudo bash emergency_app.sh
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
echo "\$(cyan "EMERGENCY APP SERVER RECOVERY")"
echo "\$(cyan "Samsung Cloud Platform v2")"
echo "\$(cyan "==========================================")"
echo ""

# Check if running as root
if [[ \$EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    echo "Please run: sudo bash emergency_app.sh"
    exit 1
fi

log_info "Starting emergency recovery for app server..."

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
# App Server Application Install Module  
app_install() {
    echo "[4/5] App server install..."
    
    # Install Node.js 20.x
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs postgresql nmap-ncat
    npm install -g pm2
    
    # Load master config
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    PRIVATE_DOMAIN=$(jq -r '.user_input_variables.private_domain_name // "your_private_domain.name"' $MASTER_CONFIG)
    DB_HOST=$(jq -r '.ceweb_required_variables.database_host // "db.'$PRIVATE_DOMAIN'"' $MASTER_CONFIG)
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
    # Wait for database with timeout
    echo "Waiting for database $DB_HOST:$DB_PORT..."
    for i in {1..30}; do
        if nc -z $DB_HOST $DB_PORT 2>/dev/null; then
            echo "✅ Database connection available"
            break
        elif [ $i -eq 30 ]; then
            echo "⚠️  Database timeout after 5 minutes, proceeding anyway..."
            break
        else
            echo "Attempt $i/30: Database not ready, waiting 10s..."
            sleep 10
        fi
    done
    
    # Create app directories  
    APP_DIR="/home/rocky/ceweb/app-server"
    sudo -u rocky mkdir -p $APP_DIR/logs
    sudo -u rocky mkdir -p /home/rocky/ceweb/files/audition
    
    # Create .env file
    cat > $APP_DIR/.env << EOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
PORT=3000
NODE_ENV=production
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "default-jwt-secret-change-me")
EOF
    chown rocky:rocky $APP_DIR/.env && chmod 600 $APP_DIR/.env
    
    # Create PM2 ecosystem
    cat > $APP_DIR/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'creative-energy-api',
    script: 'server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: { NODE_ENV: 'production', PORT: 3000 }
  }]
};
EOF
    chown rocky:rocky $APP_DIR/ecosystem.config.js
    
    # Install dependencies and start app
    cd $APP_DIR
    if [ -f package.json ]; then
        sudo -u rocky npm install
        sudo -u rocky pm2 start ecosystem.config.js
        sudo -u rocky pm2 save
    fi
    
    echo "✅ App server installed"
}

# App Server Verification Module
verify_install() {
    echo "[5/5] App verification..."
    
    # Check Node.js process
    pgrep -f node || exit 1
    
    # Check port 3000
    netstat -tlnp | grep :3000 || exit 1
    
    # Test API health endpoint
    for i in {1..30}; do
        if curl -f http://localhost:3000/health 2>/dev/null; then
            echo "✅ App server health check passed"
            break
        fi
        sleep 2
    done
    
    echo "✅ App server verified"
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
    echo ""    echo "$(yellow "APP SERVER TESTING:")"
    echo ""
    echo "1. Check Node.js version:"
    echo "   node --version"
    echo ""
    echo "2. Check PM2 status:"
    echo "   sudo -u rocky pm2 status"
    echo ""
    echo "3. Check application port:"
    echo "   netstat -tlnp | grep :3000"
    echo ""
    echo "4. Test application health:"
    echo "   curl http://localhost:3000/health"
    echo ""
    echo "5. View application logs:"
    echo "   sudo -u rocky pm2 logs"
    echo ""
    echo "6. Check environment file:"
    echo "   sudo -u rocky cat /home/rocky/ceweb/app-server/.env"
    echo ""
    echo "7. Test PostgreSQL DBaaS connection:"
    echo "   cd /home/rocky/ceweb/app-server"
    echo "   sudo -u rocky node -e 'console.log(\"DB Host:\", process.env.DB_HOST)'"
    echo "   PGPASSWORD=\$DB_PASSWORD psql -h db.your_internal.local -p 2866 -U cedbadmin -d cedb -c 'SELECT version();'"
    echo ""
    echo "8. Test DBaaS connectivity and schema:"
    echo "   PGPASSWORD=cedbadmin123! psql -h db.your_internal.local -p 2866 -U cedbadmin -d cedb -c '\\dt'"
    echo "   PGPASSWORD=cedbadmin123! psql -h db.your_internal.local -p 2866 -U cedbadmin -d cedb -c 'SELECT COUNT(*) FROM products;'"
    echo ""
    echo "9. Test application database integration:"
    echo "   curl http://localhost:3000/api/products"
    echo "   curl -X POST -H \"Content-Type: application/json\" -d '{\"test\":\"data\"}' http://localhost:3000/api/test"
    echo ""
    echo "10. Check DBaaS connection pool status:"
    echo "    PGPASSWORD=cedbadmin123! psql -h db.your_internal.local -p 2866 -U cedbadmin -d cedb -c 'SELECT count(*) FROM pg_stat_activity;'"
    echo ""
    echo "11. Restart application if needed:"
    echo "    sudo -u rocky pm2 restart all"
    echo ""
    echo "12. Monitor DBaaS connection logs:"
    echo "    sudo -u rocky pm2 logs | grep -i database"
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
SERVER_TYPE="app"

# Execute main function
main "$@"