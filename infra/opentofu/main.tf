# Etapa 1: baixar e extrair a Vagrant box
resource "null_resource" "download_and_extract_box" {
  triggers = {
    box_url = var.vagrant_box_url
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      New-Item -ItemType Directory -Force -Path "${path.module}/boxes/extracted" | Out-Null
      if (!(Test-Path "${path.module}/boxes/ubuntu-24.04.box")) {
        Invoke-WebRequest -Uri "${var.vagrant_box_url}" -OutFile "${path.module}/boxes/ubuntu-24.04.box"
      }
      tar -xf "${path.module}/boxes/ubuntu-24.04.box" -C "${path.module}/boxes/extracted"
    EOT
  }
}

# Etapa 2: importar a VM no VirtualBox
resource "null_resource" "import_vm" {
  depends_on = [null_resource.download_and_extract_box]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "VBoxManage import \"${path.module}/boxes/extracted/box.ovf\" --vsys 0 --vmname ${var.vm_name} --cpus ${var.vm_cpus} --memory ${var.vm_memory_mb}"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = "VBoxManage unregistervm ${self.triggers.vm_name} --delete"
  }

  triggers = {
    vm_name = var.vm_name
  }
}

# Etapa 3: configurar rede hostonly + restringir DHCP a um único IP
resource "null_resource" "configure_network" {
  depends_on = [null_resource.import_vm]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      VBoxManage modifyvm ${var.vm_name} --nic1 hostonly --hostonlyadapter1 "${var.hostonly_adapter_name}"
      VBoxManage dhcpserver modify --interface "${var.hostonly_adapter_name}" --lower-ip ${var.vm_static_ip} --upper-ip ${var.vm_static_ip}
    EOT
  }
}

# Etapa 4: ligar a VM
resource "null_resource" "start_vm" {
  depends_on = [null_resource.configure_network]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      VBoxManage startvm ${var.vm_name} --type headless
      Start-Sleep -Seconds 30
    EOT
  }
}