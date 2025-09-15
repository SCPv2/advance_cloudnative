########################################################
# Provider : Samsung Cloud Platform v2
########################################################
terraform {
  required_providers {
    samsungcloudplatformv2 = {
      version = "1.0.3"
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

# Subnet12 - NAT Gateway 및 Kubernetes 자원용 (app_subnet_cidr 사용)
resource "samsungcloudplatformv2_vpc_subnet" "subnet12" {
  name        = "Subnet12"
  cidr        = var.app_subnet_cidr
  type        = "GENERAL"
  description = "Subnet for NAT Gateway and Kubernetes Resources"
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
# Firewall Rules - Kubernetes 자원용
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
    description         = "Allow HTTP/HTTPS outbound from kubernetes subnet"
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

# Kubernetes API Server Access Outbound
resource "samsungcloudplatformv2_security_group_security_group_rule" "rocky_sg_k8s_api_out" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = samsungcloudplatformv2_security_group_security_group.rocky_sg.id
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  description       = "Outbound to K8s API Server"
  remote_ip_prefix  = "0.0.0.0/0"

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.rocky_sg_https_out]
}

########################################################
# Security Group Rules - Kubernetes 자원용
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

  depends_on = [samsungcloudplatformv2_security_group_security_group_rule.rocky_sg_k8s_api_out]
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
    size                  = var.boot_volume_rocky.size
    type                  = var.boot_volume_rocky.type
    delete_on_termination = var.boot_volume_rocky.delete_on_termination
  }

  image_id = var.rocky_image_id

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
# Shared File Storage Volume 생성 (Kubernetes 공유)
resource "samsungcloudplatformv2_filestorage_volume" "shared_volume" {
  name                       = "cefs"
  protocol                   = "NFS"
  type_name                  = "HDD"
  tags                       = var.common_tags
}

########################################################
# Kubernetes Engine 생성
########################################################
resource "samsungcloudplatformv2_ske_cluster" "cluster" {
  name                   = var.cluster_name
  kubernetes_version     = var.cluster_kubernetes_version
  vpc_id                = samsungcloudplatformv2_vpc_vpc.vpc.id
  subnet_id             = samsungcloudplatformv2_vpc_subnet.subnet12.id
  security_group_id_list = [samsungcloudplatformv2_security_group_security_group.private_sg.id]
  volume_id             = samsungcloudplatformv2_filestorage_volume.shared_volume.id
  cloud_logging_enabled = var.cluster_cloud_logging_enabled

  private_endpoint_access_control_resources = [
    {
      id   = samsungcloudplatformv2_virtualserver_server.vm_bastion.id
      name = samsungcloudplatformv2_virtualserver_server.vm_bastion.name
      type = "vm"
    }
  ]

  tags = var.common_tags

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.subnet12,
    samsungcloudplatformv2_security_group_security_group.private_sg,
    samsungcloudplatformv2_filestorage_volume.shared_volume,
    samsungcloudplatformv2_virtualserver_server.vm_bastion
  ]
}

########################################################
# Node Pool 생성
########################################################
resource "samsungcloudplatformv2_ske_nodepool" "nodepool" {
  name               = var.nodepool_name
  cluster_id         = samsungcloudplatformv2_ske_cluster.cluster.id
  kubernetes_version = var.cluster_kubernetes_version

  # Node 설정
  desired_node_count = var.nodepool_desired_node_count
  server_type_id     = var.nodepool_server_type_id

  # Image 설정
  image_os         = var.nodepool_image_os
  image_os_version = var.nodepool_image_os_version

  # Storage 설정
  volume_type_name = var.nodepool_volume_type_name
  volume_size      = var.nodepool_volume_size

  # Key Pair 설정
  keypair_name = var.keypair_name

  # Auto Scaling/Recovery 설정
  is_auto_scale    = var.nodepool_is_auto_scale
  is_auto_recovery = var.nodepool_is_auto_recovery

  depends_on = [samsungcloudplatformv2_ske_cluster.cluster]
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

output "kubernetes_cluster_id" {
  value = samsungcloudplatformv2_ske_cluster.cluster.id
  description = "Kubernetes Cluster ID"
}

output "kubernetes_cluster_endpoint" {
  value = samsungcloudplatformv2_ske_cluster.cluster.cluster.private_endpoint_url
  description = "Kubernetes Cluster Private Endpoint URL"
}

output "nodepool_id" {
  value = samsungcloudplatformv2_ske_nodepool.nodepool.id
  description = "Node Pool ID"
}