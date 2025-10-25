########################################################
# Provider : Samsung Cloud Plat
########################################################
# Virtual Server Standard Image ID 조회
########################################################
# Windows 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "windows" {
  os_distro = var.image_windows_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_windows_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_windows_scp_os_version]
    use_regex = false
  }
}

# Rocky 이미지 조회
data "samsungcloudplatformv2_virtualserver_images" "rocky" {
  os_distro = var.image_rocky_os_distro
  status    = "active"

  filter {
    name      = "os_distro"
    values    = [var.image_rocky_os_distro]
    use_regex = false
  }
  filter {
    name      = "scp_os_version"
    values    = [var.image_rocky_scp_os_version]
    use_regex = false
  }
}

# 이미지 Local 변수 지정
locals {
  windows_ids = try(data.samsungcloudplatformv2_virtualserver_images.windows.ids, [])
  rocky_ids   = try(data.samsungcloudplatformv2_virtualserver_images.rocky.ids, [])

  windows_image_id_first = length(local.windows_ids) > 0 ? local.windows_ids[0] : ""
  rocky_image_id_first   = length(local.rocky_ids)   > 0 ? local.rocky_ids[0]   : ""
}
form v2
########################################################
terraform {
  required_providers {
    samsungcloudplatformv2 = {
      version = "2.0.3"
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
    }
  }
  required_version = ">= 1.11"
}

provider "samsungcloudplatformv2" {
}

########################################################
# VPC 자원 생성
########################################################
resource "samsungcloudplatformv2_vpc_vpc" "vpc" {
  name        = "VPC1"
  cidr        = var.vpc_cidr
  description = "Simple VPC"
  tags        = var.common_tags
}

########################################################
# Internet Gateway 생성, VPC 연결
########################################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "igw" {
  type              = "IGW"
  vpc_id            = samsungcloudplatformv2_vpc_vpc.vpc.id
  firewall_enabled  = true
  firewall_loggable = false
  tags              = var.common_tags

  depends_on = [samsungcloudplatformv2_vpc_vpc.vpc]
}

########################################################
# Subnet 자원 생성
########################################################
# Subnet11 - Rocky Linux 서버용 (web_subnet_cidr 사용)
resource "samsungcloudplatformv2_vpc_subnet" "subnet11" {
  name        = "Subnet11"
  cidr        = var.web_subnet_cidr
  type        = "GENERAL"
  description = "Subnet for Rocky Linux Server"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

# Subnet12 - NAT Gateway 및 Private 자원용 (app_subnet_cidr 사용)
resource "samsungcloudplatformv2_vpc_subnet" "subnet12" {
  name        = "Subnet12"
  cidr        = var.app_subnet_cidr
  type        = "GENERAL"
  description = "Subnet for NAT Gateway and Private Resources"
  vpc_id      = samsungcloudplatformv2_vpc_vpc.vpc.id
  tags        = var.common_tags

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

########################################################
# 기존 Key Pair 조회
########################################################
data "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
}

########################################################
# Public IP
########################################################
# Rocky Linux 서버용 Public IP
resource "samsungcloudplatformv2_vpc_publicip" "rocky_public_ip" {
  type        = "IGW"
  description = "Public IP for Rocky Linux Server"

  depends_on = [samsungcloudplatformv2_vpc_subnet.subnet11]
}

# NAT Gateway용 Public IP
resource "samsungcloudplatformv2_vpc_publicip" "nat_public_ip" {
  type        = "IGW"
  description = "Public IP for NAT Gateway"

  depends_on = [samsungcloudplatformv2_vpc_subnet.subnet12]
}

########################################################
# NAT Gateway 생성
########################################################
resource "samsungcloudplatformv2_vpc_nat_gateway" "nat" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.subnet12.id
  description = "NAT Gateway for Private Resources"
  publicip_id = samsungcloudplatformv2_vpc_publicip.nat_public_ip.id
  tags        = var.common_tags

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet12,
    samsungcloudplatformv2_vpc_publicip.nat_public_ip
  ]
}

########################################################
# Security Groups
########################################################
# bastionVM
resource "samsungcloudplatformv2_security_group_security_group" "rocky_sg" {
  name        = "bastionSG"
  loggable    = false
  tags        = var.common_tags
}

# K8s 
resource "samsungcloudplatformv2_security_group_security_group" "private_sg" {
  name        = "K8sSG"
  loggable    = false
  tags        = var.common_tags
}

########################################################
# IGW Firewall 조회
########################################################
data "samsungcloudplatformv2_firewall_firewalls" "fw_igw" {
  product_type = ["IGW"]
  size         = 1

  depends_on  = [samsungcloudplatformv2_vpc_internet_gateway.igw]
}

locals {
  igw_firewall_id = data.samsungcloudplatformv2_firewall_firewalls.fw_igw.ids[0]
}

########################################################
# Firewall Rules 
########################################################
# SSH Inbound from user_public_ip
resource "samsungcloudplatformv2_firewall_firewall_rule" "rocky_ssh_in" {
  firewall_id = local.igw_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    description         = "Allow SSH from user public IP"
    destination_address = [var.web_subnet_cidr]
    direction           = "INBOUND"
    service = [{
      service_type  = "TCP"
      service_value = "22"
    }]
    source_address = ["${var.user_public_ip}/32"]
    status         = "ENABLE"
  }

  depends_on = [data.samsungcloudplatformv2_firewall_firewalls.fw_igw]
}

# HTTP/HTTPS Outbound to 0.0.0.0/0
resource "samsungcloudplatformv2_firewall_firewall_rule" "rocky_http_https_out" {
  firewall_id = local.igw_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    description         = "Allow HTTP/HTTPS outbound"
    destination_address = ["0.0.0.0/0"]
    direction           = "OUTBOUND"
    service = [
      {
        service_type  = "TCP"
        service_value = "80"
      },
      {
        service_type  = "TCP"
        service_value = "443"
      }
    ]
    source_address = [var.web_subnet_cidr]
    status         = "ENABLE"
  }

  depends_on = [samsungcloudplatformv2_firewall_firewall_rule.rocky_ssh_in]
}

########################################################
# Firewall Rules - Private 자원용 (둘째 FW)
########################################################
# HTTP Inbound from 0.0.0.0/0
resource "samsungcloudplatformv2_firewall_firewall_rule" "private_http_in" {
  firewall_id = local.igw_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    description         = "Allow HTTP from anywhere"
    destination_address = [var.app_subnet_cidr]
    direction           = "INBOUND"
    service = [{
      service_type  = "TCP"
      service_value = "80"
    }]
    source_address = ["0.0.0.0/0"]
    status         = "ENABLE"
  }

  depends_on = [samsungcloudplatformv2_firewall_firewall_rule.rocky_http_https_out]
}

# HTTP/HTTPS Outbound to 0.0.0.0/0
resource "samsungcloudplatformv2_firewall_firewall_rule" "private_http_https_out" {
  firewall_id = local.igw_firewall_id
  firewall_rule_create = {
    action              = "ALLOW"
    description         = "Allow HTTP/HTTPS outbound from private subnet"
    destination_address = ["0.0.0.0/0"]
    direction           = "OUTBOUND"
    service = [
      {
        service_type  = "TCP"
        service_value = "80"
      },
      {
        service_type  = "TCP"
        service_value = "443"
      }
    ]
    source_address = [var.app_subnet_cidr]
    status         = "ENABLE"
  }

  depends_on = [samsungcloudplatformv2_firewall_firewall_rule.private_http_in]
}

########################################################
# Security Group Rules - bastionVM (Rocky Linux)
########################################################
# SSH Inbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "rocky_sg_ssh_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.rocky_sg.id
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  description       = "SSH inbound from user PC"
  remote_ip_prefix  = "${var.user_public_ip}/32"

  depends_on = [samsungcloudplatformv2_security_group_security_group.rocky_sg]
}

# HTTP Outbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "rocky_sg_http_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.rocky_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.rocky_sg_ssh_in]
}

# HTTPS Outbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "rocky_sg_https_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.rocky_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.rocky_sg_http_out]
}

########################################################
# Security Group Rules - Private 자원용
########################################################
# HTTP Inbound from anywhere
resource "samsungcloudplatformv2_security_group_security_group_rule" "private_sg_http_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.private_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP inbound from anywhere"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.rocky_sg_https_out]
}

# HTTP Outbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "private_sg_http_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.private_sg.id
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  description       = "HTTP outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.private_sg_http_in]
}

# HTTPS Outbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "private_sg_https_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.private_sg.id
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  description       = "HTTPS outbound to Internet"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.private_sg_http_out]
}

########################################################
# Rocky Linux Server (bastionVM)
########################################################
resource "samsungcloudplatformv2_virtualserver_server" "vm_bastion" {
  name           = "bastionVM110r"
  keypair_name   = data.samsungcloudplatformv2_virtualserver_keypair.kp.name
  server_type_id = var.server_type_id
  state          = "ACTIVE"
  tags           = var.common_tags

  boot_volume = {
    size                  = var.boot_volume_windows.size
    type                  = var.boot_volume_windows.type
    delete_on_termination = var.boot_volume_windows.delete_on_termination
  }

  image_id = local.rocky_image_id_first

  networks = {
    nic0 = {
      public_ip_id = samsungcloudplatformv2_vpc_publicip.rocky_public_ip.id,
      subnet_id    = samsungcloudplatformv2_vpc_subnet.subnet11.id,
      fixed_ip     = var.bastion_ip
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.rocky_sg.id]

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet11,
    samsungcloudplatformv2_vpc_publicip.rocky_public_ip,
    samsungcloudplatformv2_security_group_security_group.rocky_sg
  ]
}


########################################################
# File Storage Volume 구성
########################################################

# Shared File Storage Volume 생성 (Web/App 서버 공유)
resource "samsungcloudplatformv2_filestorage_volume" "shared_volume" {
  name                       = "cefs"
  protocol                   = "NFS"
  type_name                  = "HDD"
  tags                       = var.common_tags
}

########################################################
# Outputs
########################################################
output "rocky_server_public_ip" {
  value = samsungcloudplatformv2_vpc_publicip.rocky_public_ip
  description = "Public IP of Rocky Linux Server"
}

output "vpc_id" {
  value = samsungcloudplatformv2_vpc_vpc.vpc.id
  description = "VPC ID"
}

output "subnet11_id" {
  value = samsungcloudplatformv2_vpc_subnet.subnet11.id
  description = "Subnet11 ID"
}

output "subnet12_id" {
  value = samsungcloudplatformv2_vpc_subnet.subnet12.id
  description = "Subnet12 ID"
}

output "nat_gateway_id" {
  value = samsungcloudplatformv2_vpc_nat_gateway.nat.id
  description = "NAT Gateway ID"
}
