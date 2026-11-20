# A VM do cluster k3s.

# Imagem oficial mais recente do Ubuntu 24.04, publicada pela Canonical no SSM.
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "admin" {
  key_name   = "${var.name_prefix}-admin"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "k3s_node" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.node.id]
  key_name               = aws_key_pair.admin.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true # o disco some junto com a VM no destroy
  }

  # IMDSv2 obrigatório: protege as credenciais da instância contra ataques SSRF.
  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.name_prefix}-k3s-node" }

  # Uma AMI nova no SSM não deve recriar a VM sozinha num "apply" qualquer.
  lifecycle {
    ignore_changes = [ami]
  }
}
