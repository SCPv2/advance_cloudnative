#!/bin/bash
# Samsung Cloud Platform v2 (OpenStack) - Universal UserData Template
# 45KB limit optimized for OpenStack cloud-init
#
# UNIVERSAL TEMPLATE: Supports both VM-based DB and DBaaS scenarios
# - database_service: Uses VM-based PostgreSQL (includes db_server_module.sh)
# - object_storage: Uses PostgreSQL DBaaS (skips DB server installation)
#
# Template Variables (replaced by userdata_manager.ps1):
# - db: "web", "app", or "db"
# - your_private_domain.name, 10.1.1.111, 10.1.2.121, 10.1.3.132: Network configuration
# - APPLICATION_INSTALL_MODULE: Server-specific installation module content
# - {"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"ceweb_required_variables":{"rollback_enabled":"true","nginx_port":"80","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","_source":"variables.tf CEWEB_REQUIRED category","object_storage_audition_folder":"files/audition","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","object_storage_region":"kr-west1","app_server_port":"3000","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","admin_email":"ars4mundus@gmail.com","db_type":"postgresql","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_ip":"10.1.3.132","git_branch":"main","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","web_lb_service_ip":"10.1.1.100","company_name":"Creative Energy","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"object_storage_bucket_name":"ceweb","node_env":"production","web_ip":"10.1.1.111","database_host":"db.your_private_domain.name","ssl_enabled":"false"},"image_engine_metadata":{"cache_file":"image_engine_id.json","scpcli_available":true,"last_updated":"2025-09-16T15:38:15Z"},"terraform_infra_variables":{"_comment":"Variables used by terraform for infrastructure deployment","db_ip2":"10.1.3.33","windows_image_id":"28d98f66-44ca-4858-904f-636d4f674a62","rocky_image_id":"253a91ea-1221-49d7-af53-a45c389e7e1a","_source":"variables.tf TERRAFORM_INFRA category and SCP CLI","postgresql_engine_id":"feebbfb2e7164b83a9855cacd0b64fde"},"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","image_engine_cache":"image_engine_id.json","created":"2025-09-16 15:38:58","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"container_registry_endpoint":"your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com","keypair_name":"mykey","public_domain_name":"your_public_domain.name","object_storage_secret_access_key":"put_your_authentificate_secret_key_here","_source":"variables.tf USER_INPUT category","private_domain_name":"your_private_domain.name","object_storage_bucket_string":"put_your_account_id_here","object_storage_access_key_id":"put_your_authentificate_access_key_here","user_public_ip":"your_public_ip/32","_comment":"Variables that users input interactively during deployment"}}: Environment-specific configuration JSON

set -euo pipefail
SERVER_TYPE="db"
LOGFILE="/var/log/userdata_db.log"
exec 1> >(tee -a $LOGFILE) 2>&1

echo "=== ${SERVER_TYPE^} Server Init: $(date) ==="

# Module 0: Local DNS Resolution
local_dns_setup() {
    echo "[0/5] Local DNS Resolution setup..."
    
    # Define domain mappings
    PRIVATE_DOMAIN="your_private_domain.name"
    WEB_IP="10.1.1.111"
    APP_IP="10.1.2.121"
    DB_IP="10.1.3.132"
    
    # Create temporary hosts entries
    cat >> /etc/hosts << EOF

# === SCPv2 Temporary DNS Mappings ===
10.1.1.111 www.${PRIVATE_DOMAIN}
10.1.2.121 app.${PRIVATE_DOMAIN}
10.1.3.132 db.${PRIVATE_DOMAIN}
# === End SCPv2 Mappings ===
EOF
    
    echo "✅ Local DNS mappings added to /etc/hosts"
    echo "   www.${PRIVATE_DOMAIN} -> 10.1.1.111"
    echo "   app.${PRIVATE_DOMAIN} -> 10.1.2.121"
    # DB endpoint type detection
    if [[ "10.1.3.132" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "   db.${PRIVATE_DOMAIN} -> 10.1.3.132 (VM-based DB)"
    else
        echo "   db.${PRIVATE_DOMAIN} -> 10.1.3.132 (PostgreSQL DBaaS)"
    fi
}

# Module 1: System Update (Compact)
sys_update() {
    echo "[1/5] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do sleep 10; done
    for i in {1..3}; do dnf clean all && dnf install -y epel-release && break; sleep 30; done
    dnf -y update upgrade || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    echo "✅ System updated with NTP"
}

# Module 2: Repository Clone
repo_clone() {
    echo "[2/5] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    echo "✅ Repository ready"
}

# Module 3: Config Injection (Template substitution)
config_inject() {
    echo "[3/5] Config injection..."
    # Master configuration JSON will be injected here by userdata_manager.ps1
    # This contains all environment-specific variables including:
    # - Infrastructure settings (IPs, domains, ports)
    # - Database configuration (VM-based or DBaaS connection strings)
    # - Object storage settings (if applicable)
    # - Application-specific parameters
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
{"_variable_classification":{"description":"ceweb application variable classification system","categories":{"user_input":"Variables that users input interactively during deployment","terraform_infra":"Variables used by terraform for infrastructure deployment","ceweb_required":"Variables required by ceweb application for business logic and database connections"}},"ceweb_required_variables":{"rollback_enabled":"true","nginx_port":"80","object_storage_public_endpoint":"https://object-store.kr-west1.e.samsungsdscloud.com","_source":"variables.tf CEWEB_REQUIRED category","object_storage_audition_folder":"files/audition","app_lb_service_ip":"10.1.2.100","timezone":"Asia/Seoul","database_port":"2866","object_storage_media_folder":"media/img","db_max_connections":"100","database_user":"cedbadmin","app_ip":"10.1.2.121","object_storage_region":"kr-west1","app_server_port":"3000","auto_deployment":"true","database_name":"cedb","git_repository":"https://github.com/SCPv2/ceweb.git","admin_email":"ars4mundus@gmail.com","db_type":"postgresql","backup_retention_days":"30","object_storage_private_endpoint":"https://object-store.private.kr-west1.e.samsungsdscloud.com","db_ip":"10.1.3.132","git_branch":"main","session_secret":"your-secret-key-change-in-production","_comment":"Variables required by ceweb application for business logic and functionality","web_lb_service_ip":"10.1.1.100","company_name":"Creative Energy","_database_connection":{"db_ssl_enabled":false,"database_password":"cedbadmin123!","db_pool_idle_timeout":30000,"db_pool_min":20,"db_pool_connection_timeout":60000,"db_pool_max":100},"object_storage_bucket_name":"ceweb","node_env":"production","web_ip":"10.1.1.111","database_host":"db.your_private_domain.name","ssl_enabled":"false"},"image_engine_metadata":{"cache_file":"image_engine_id.json","scpcli_available":true,"last_updated":"2025-09-16T15:38:15Z"},"terraform_infra_variables":{"_comment":"Variables used by terraform for infrastructure deployment","db_ip2":"10.1.3.33","windows_image_id":"28d98f66-44ca-4858-904f-636d4f674a62","rocky_image_id":"253a91ea-1221-49d7-af53-a45c389e7e1a","_source":"variables.tf TERRAFORM_INFRA category and SCP CLI","postgresql_engine_id":"feebbfb2e7164b83a9855cacd0b64fde"},"config_metadata":{"template_source":"variables.tf","version":"4.1.0","description":"Samsung Cloud Platform 3-Tier Architecture Master Configuration with DBaaS","image_engine_cache":"image_engine_id.json","created":"2025-09-16 15:38:58","usage":"This file contains all environment-specific settings for the application deployment","generator":"variables_manager.ps1"},"user_input_variables":{"container_registry_endpoint":"your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com","keypair_name":"mykey","public_domain_name":"your_public_domain.name","object_storage_secret_access_key":"put_your_authentificate_secret_key_here","_source":"variables.tf USER_INPUT category","private_domain_name":"your_private_domain.name","object_storage_bucket_string":"put_your_account_id_here","object_storage_access_key_id":"put_your_authentificate_access_key_here","user_public_ip":"your_public_ip/32","_comment":"Variables that users input interactively during deployment"}}
CONFIG_EOF
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    jq . /home/rocky/master_config.json >/dev/null || exit 1
    echo "✅ Config injected"
}

# Module 4 & 5: Application Install and Verification (Server-specific - will be injected)
# 
# This section will be dynamically replaced by userdata_manager.ps1 with server-specific content:
# - For WEB servers: web_server_module.sh (Nginx, static file serving)
# - For APP servers: app_server_module.sh (Node.js, PM2, API server)
# - For DB servers:  db_server_module.sh (PostgreSQL VM installation)
#                    Note: Only used in VM-based DB scenarios (database_service)
#                    DBaaS scenarios (object_storage) skip DB server installation
#
# Each module contains both app_install() and verify_install() functions
# Database Server Application Install Module
app_install() {
    echo "[4/5] Database server install..."
    
    # Install PostgreSQL 16 repository
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    dnf install -y postgresql16-server postgresql16 postgresql16-contrib
    
    # Initialize and start PostgreSQL
    /usr/pgsql-16/bin/postgresql-16-setup initdb
    systemctl start postgresql-16 && systemctl enable postgresql-16
    
    # Load master config
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_USER=$(jq -r '.ceweb_required_variables.database_user // "cedbadmin"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
    # Configure PostgreSQL
    PG_CONFIG="/var/lib/pgsql/16/data"
    cp $PG_CONFIG/postgresql.conf $PG_CONFIG/postgresql.conf.backup
    cp $PG_CONFIG/pg_hba.conf $PG_CONFIG/pg_hba.conf.backup
    
    # Update configuration
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG/postgresql.conf
    sed -i "s/#port = 5432/port = $DB_PORT/" $PG_CONFIG/postgresql.conf
    sed -i "s/#max_connections = 100/max_connections = 100/" $PG_CONFIG/postgresql.conf
    
    # Allow remote connections
    echo "host all all 0.0.0.0/0 md5" >> $PG_CONFIG/pg_hba.conf
    
    # Restart PostgreSQL
    systemctl restart postgresql-16
    sleep 5
    
    # Verify port binding
    netstat -tlnp | grep ":$DB_PORT" || exit 1
    
    # Set up database and users
    sudo -u postgres PGPORT=$DB_PORT psql -c "ALTER USER postgres PASSWORD '$DB_PASSWORD';"
    sudo -u postgres PGPORT=$DB_PORT psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres PGPORT=$DB_PORT psql -c "ALTER USER $DB_USER CREATEDB;"
    sudo -u postgres PGPORT=$DB_PORT createdb -O $DB_USER $DB_NAME
    
    # Install schema if exists
    SCHEMA_FILE="/home/rocky/ceweb/db-server/vm_db/postgresql_vm_init_schema.sql"
    if [ -f "$SCHEMA_FILE" ]; then
        # Copy schema file to accessible location for postgres user
        cp "$SCHEMA_FILE" /tmp/postgresql_vm_init_schema.sql
        chmod 644 /tmp/postgresql_vm_init_schema.sql
        
        # Install schema using postgres user
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -f /tmp/postgresql_vm_init_schema.sql
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
        sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"
        
        # Clean up
        rm -f /tmp/postgresql_vm_init_schema.sql
    fi
    
    echo "✅ Database server installed"
}

# Database Server Verification Module
verify_install() {
    echo "[5/5] Database verification..."
    
    MASTER_CONFIG="/home/rocky/ceweb/web-server/master_config.json"
    DB_PORT=$(jq -r '.ceweb_required_variables.database_port // "2866"' $MASTER_CONFIG)
    DB_NAME=$(jq -r '.ceweb_required_variables.database_name // "cedb"' $MASTER_CONFIG)
    DB_PASSWORD=$(jq -r '.ceweb_required_variables.database_password // "cedbadmin123!"' $MASTER_CONFIG)
    
    # Check PostgreSQL service
    systemctl is-active postgresql-16 || exit 1
    
    # Check port binding
    netstat -tlnp | grep ":$DB_PORT" || exit 1
    
    # Test database connection
    sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "SELECT version();" || exit 1
    
    # Show table count
    sudo -u postgres PGPASSWORD="$DB_PASSWORD" psql -h localhost -p $DB_PORT -d $DB_NAME -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
    
    echo "✅ Database server verified"
}

# Module 6: Local DNS Cleanup
local_dns_cleanup() {
    echo "[6/6] Local DNS Resolution cleanup..."
    
    # Remove SCPv2 temporary DNS mappings from /etc/hosts
    sudo sed -i '/# === SCPv2 Temporary DNS Mappings ===/,/# === End SCPv2 Mappings ===/d' /etc/hosts
    
    echo "✅ Local DNS mappings cleaned up from /etc/hosts"
}

# Main execution
main() {
    local_dns_setup
    sys_update
    repo_clone
    config_inject
    app_install
    # Custom web setup for web servers (if function exists)
    if [ "$SERVER_TYPE" = "web" ] && type custom_web_setup >/dev/null 2>&1; then
        custom_web_setup
    fi
    verify_install
    local_dns_cleanup
    echo "${SERVER_TYPE^} ready: $(date)" > /home/rocky/${SERVER_TYPE^}_Ready.log
    echo "=== ${SERVER_TYPE^} Init Complete: $(date) ==="
}

main