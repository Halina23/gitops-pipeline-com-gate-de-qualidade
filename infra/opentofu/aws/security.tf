# Firewall da VM. SSH e API do Kubernetes só para o IP de administração.

# Descobre o IP público de quem roda o tofu (usado se admin_cidr estiver vazio).
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  admin_cidr = var.admin_cidr != "" ? var.admin_cidr : "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "node" {
  name        = "${var.name_prefix}-k3s-node"
  description = "k3s node: SSH e API restritos ao admin, HTTP/HTTPS publicos"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.name_prefix}-k3s-node" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  security_group_id = aws_security_group.node.id
  description       = "SSH (Ansible e administracao)"
  cidr_ipv4         = local.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api_admin" {
  security_group_id = aws_security_group.node.id
  description       = "API do Kubernetes (kubectl, helm)"
  cidr_ipv4         = local.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.node.id
  description       = "HTTP publico (Ingress)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.node.id
  description       = "HTTPS publico (Ingress)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Saída liberada: a VM precisa baixar pacotes, imagens do GHCR e falar com APIs.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.node.id
  description       = "Saida liberada"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
