########################################################
# Output 정의
########################################################

output "deployment_info" {
  description = "Basic deployment information"
  value = {
    vpc_id = samsungcloudplatformv2_vpc_vpc.vpc.id
    vpc_cidr = samsungcloudplatformv2_vpc_vpc.vpc.cidr
    deployment_type = "Simple Web Server Architecture"
  }
}

output "server_information" {
  description = "Server IP addresses and access information"
  value = {
    web_server = {
      name = var.vm_web.name
      private_ip = var.web_ip
      public_ip = "Available after deployment"
      os = "Rocky Linux 9.4"
      service_port = var.nginx_port
      access = "SSH via public IP"
      userdata = "userdata_web.sh"
      status = "Ready to deploy"
    }
  }
}

output "network_information" {
  description = "Network configuration details"
  value = {
    subnet = {
      name = "WebSubnet"
      cidr = var.web_subnet_cidr
      hosts = ["web (${var.web_ip})"]
    }
    nat_gateway = "Available after deployment"
  }
}

output "security_information" {
  description = "Security configuration"
  value = {
    security_groups = ["webSG"]
    firewall_rules = {
      inbound = [
        "HTTP to web (0.0.0.0/0 -> ${var.web_ip}:80)",
        "SSH to web (0.0.0.0/0 -> ${var.web_ip}:22)"
      ]
      outbound = [
        "HTTP/HTTPS from web VM to Internet"
      ]
    }
  }
}

output "application_status" {
  description = "Application deployment status"
  value = {
    web_server = {
      service = "Nginx Web Server"
      port = var.nginx_port
      status = "Will be installed automatically via userdata"
    }
  }
}

output "next_steps" {
  description = "Next steps after deployment"
  value = [
    "1. Run 'terraform init' to initialize the configuration",
    "2. Run 'terraform plan' to review the deployment plan",
    "3. Run 'terraform apply' to deploy the infrastructure",
    "4. Wait 5-10 minutes for web server to be automatically installed via userdata script",
    "5. Access web application via: http://[WEB_SERVER_PUBLIC_IP]/",
    "6. SSH to web server using: ssh -i [your-key] rocky@[WEB_SERVER_PUBLIC_IP]",
    "7. Monitor installation logs in /var/log/userdata_web.log on the server"
  ]
}