########################################################
# 공통 태그 설정
########################################################
variable "common_tags" {
  type        = map(string)
  description = "Common tags to be applied to all resources"
  default = {
    name      = "advance_lab"
    createdby = "terraform"
  }
}

########################################################
# 1. 사용자 입력 변수 (USER_INPUT_VARIABLES)
#    사용자가 대화형으로 수정 가능한 필수 입력 항목
########################################################

variable "private_domain_name" {
  type        = string
  description = "[USER_INPUT] Private domain name (e.g., internal.local)"
  default     = "your_private_domain.name"
}

variable "public_domain_name" {
  type        = string
  description = "[USER_INPUT] Public domain name (e.g., example.com)"
  default     = "your_public_domain.name"
}

variable "keypair_name" {
  type        = string
  description = "[USER_INPUT] Key Pair to access VM"
  default     = "mykey"
}

variable "user_public_ip" {
  type        = string
  description = "[USER_INPUT] Public IP address of user PC"
  default     = "your_public_ip/32"
}

# Optional Object Storage variables
variable "object_storage_access_key_id" {
  type        = string
  description = "[USER_INPUT] Object Storage access key ID (optional)"
  default     = "put_your_authentificate_access_key_here"
}

variable "object_storage_secret_access_key" {
  type        = string
  description = "[USER_INPUT] Object Storage secret access key (optional)"
  default     = "put_your_authentificate_secret_key_here"
  sensitive   = true
}

variable "object_storage_bucket_string" {
  type        = string
  description = "[USER_INPUT] Object Storage bucket string (optional)"
  default     = "put_your_account_id_here"
}

variable "container_registry_endpoint" {
  type        = string
  description = "[USER_INPUT] Container Registry Private Endpoint URL"
  default     = "your-registry-endpoint.scr.private.kr-east1.e.samsungsdscloud.com"
}

########################################################
# 2. ceweb 애플리케이션 필수 변수 (CEWEB_REQUIRED_VARIABLES)
#    ceweb 애플리케이션과 Terraform에서 공통으로 사용하는 변수입니다.
#    master_config.json에서 요구하는 변수 중 일부가 포함됩니다.
########################################################

variable "app_server_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Port number for application server"
  default     = 3000
}

variable "database_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Port number for database server"
  default     = 2866
}

variable "database_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Database name"
  default     = "cedb"
}

variable "database_user" {
  type        = string
  description = "[CEWEB_REQUIRED] Database admin user"
  default     = "cedbadmin"
}

variable "database_password" {
  type        = string
  description = "[CEWEB_REQUIRED] Database admin password"
  default     = "cedbadmin123!"
  sensitive   = true
}

variable "database_host" {
  type        = string
  description = "[CEWEB_REQUIRED] Database server hostname (auto-generated from private_domain_name)"
  default     = ""  # Will be dynamically set in variables_manager.ps1
}

variable "nginx_port" {
  type        = number
  description = "[CEWEB_REQUIRED] Nginx web server port"
  default     = 80
}

variable "ssl_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable SSL for web server"
  default     = false
}

variable "object_storage_bucket_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage bucket name"
  default     = "ceweb"
}

variable "object_storage_region" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage region"
  default     = "kr-west1"
}

variable "git_repository" {
  type        = string
  description = "[CEWEB_REQUIRED] Git repository URL"
  default     = "https://github.com/SCPv2/ceweb.git"
}

variable "git_branch" {
  type        = string
  description = "[CEWEB_REQUIRED] Git branch name"
  default     = "main"
}

variable "timezone" {
  type        = string
  description = "[CEWEB_REQUIRED] System timezone"
  default     = "Asia/Seoul"
}

variable "web_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of web VM"
  default     = "10.1.1.111"
}

variable "app_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of app VM"
  default     = "10.1.2.121"
}

variable "db_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Private IP address of database (DBaaS endpoint)"
  default     = "10.1.3.132"
}

variable "web_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Service IP for Web Load Balancer"
  default     = "10.1.1.100"
}

variable "app_lb_service_ip" {
  type        = string
  description = "[CEWEB_REQUIRED] Service IP for App Load Balancer"
  default     = "10.1.2.100"
}

variable "node_env" {
  type        = string
  description = "[CEWEB_REQUIRED] Node.js environment"
  default     = "production"
}

variable "session_secret" {
  type        = string
  description = "[CEWEB_REQUIRED] Application session secret"
  default     = "your-secret-key-change-in-production"
  sensitive   = true
}

variable "db_type" {
  type        = string
  description = "[CEWEB_REQUIRED] Database type"
  default     = "postgresql"
}

variable "db_max_connections" {
  type        = number
  description = "[CEWEB_REQUIRED] Database max connections"
  default     = 100
}

variable "object_storage_private_endpoint" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage private endpoint"
  default     = "https://object-store.private.kr-west1.e.samsungsdscloud.com"
}

variable "object_storage_public_endpoint" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage public endpoint"
  default     = "https://object-store.kr-west1.e.samsungsdscloud.com"
}

variable "object_storage_media_folder" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage media folder"
  default     = "media/img"
}

variable "object_storage_audition_folder" {
  type        = string
  description = "[CEWEB_REQUIRED] Object Storage audition folder"
  default     = "files/audition"
}

variable "auto_deployment" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable auto deployment"
  default     = true
}

variable "rollback_enabled" {
  type        = bool
  description = "[CEWEB_REQUIRED] Enable rollback"
  default     = true
}

variable "backup_retention_days" {
  type        = number
  description = "[CEWEB_REQUIRED] Backup retention days"
  default     = 30
}

variable "company_name" {
  type        = string
  description = "[CEWEB_REQUIRED] Company name"
  default     = "Creative Energy"
}

variable "admin_email" {
  type        = string
  description = "[CEWEB_REQUIRED] Administrator email"
  default     = "ars4mundus@gmail.com"
}

########################################################
# VM IP addresses
########################################################
variable "bastion_ip" {
  type        = string
  description = "Private IP address of bastion VM"
  default     = "10.1.1.110"
}

########################################################
# Virtual Server Standard Image 변수 정의
########################################################
variable "rocky_image_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Rocky Linux image ID"
  default     = "99b329ad-14e1-4741-b3ef-2a330ef81074" 
}

########################################################
# Virtual Server 변수 정의
########################################################
variable "server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Server type ID (instance type)"
#  default     = "s1v1m2" # for kr-west1
  default     = "s2v1m2" # for kr-east1
}

variable "boot_volume_rocky" {
  type = object({
    size                  = number
    type                  = optional(string)
    delete_on_termination = optional(bool)
  })
  default = {
    size                  = 16
    type                  = "SSD"
    delete_on_termination = true
  }
}

# Derived variables for template usage
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR for template usage"
  default     = "10.1.0.0/16"
}

variable "web_subnet_cidr" {
  type        = string
  description = "Web subnet CIDR for template usage"
  default     = "10.1.1.0/24"
}

variable "app_subnet_cidr" {
  type        = string
  description = "App subnet CIDR for template usage"
  default     = "10.1.2.0/24"
}

########################################################
# 3. Terraform 인프라 변수 (TERRAFORM_INFRASTRUCTURE_VARIABLES)
#    이 파트에는 새로운 변수를 추가할 수 있습니다.
#    단, 이 파트의 변수는 main.tf에서만 사용됩니다.
########################################################

########################################################
# Kubernetes Engine 변수 정의
########################################################
variable "cluster_name" {
  type        = string
  description = "[TERRAFORM_INFRA] Kubernetes cluster name"
  default     = "cek8s"
}

variable "cluster_kubernetes_version" {
  type        = string
  description = "[TERRAFORM_INFRA] Kubernetes version"
  default     = "v1.31.8"
}

variable "cluster_cloud_logging_enabled" {
  type        = bool
  description = "[TERRAFORM_INFRA] Enable cloud logging for cluster"
  default     = true
}

########################################################
# Node Pool 변수 정의
########################################################
variable "nodepool_name" {
  type        = string
  description = "[TERRAFORM_INFRA] Node pool name"
  default     = "cenode"
}

variable "nodepool_desired_node_count" {
  type        = number
  description = "[TERRAFORM_INFRA] Desired node count in node pool"
  default     = 2
}

variable "nodepool_server_type_id" {
  type        = string
  description = "[TERRAFORM_INFRA] Node pool server type ID"
  default     = "s2v2m4"  # Standard-1 / s1v2m4 as per README
}

variable "nodepool_image_os" {
  type        = string
  description = "[TERRAFORM_INFRA] Node pool image OS"
  default     = "ubuntu"
}

variable "nodepool_image_os_version" {
  type        = string
  description = "[TERRAFORM_INFRA] Node pool image OS version"
  default     = "22.04"
}

variable "nodepool_volume_type_name" {
  type        = string
  description = "[TERRAFORM_INFRA] Node pool volume type"
  default     = "SSD"
}

variable "nodepool_volume_size" {
  type        = number
  description = "[TERRAFORM_INFRA] Node pool volume size in GB"
  default     = 104
}

variable "nodepool_is_auto_scale" {
  type        = bool
  description = "[TERRAFORM_INFRA] Enable auto scaling for node pool"
  default     = false  # 미사용 as per README
}

variable "nodepool_is_auto_recovery" {
  type        = bool
  description = "[TERRAFORM_INFRA] Enable auto recovery for node pool"
  default     = false  # 미사용 as per README
}





















