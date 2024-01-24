locals {
  vm_nodes = [
    for i in range(var.vm_count) : {
      name    = "${var.host_suffix}${i}"
      address = "${var.kvm_subnet_prefix}.${20 + i}"
    }
  ]
}

# resource "null_resource" "copy_files" {
#   for_each = { for node in local.vm_nodes : node.name => node }

#   provisioner "file" {
#     source      = "${path.module}/../helpers/install-rke2-worker.sh"
#     destination = "/tmp/install-rke2-worker.sh"

#     connection {
#       type        = "ssh"
#       user        = var.admin_name
#       private_key = file("~/.ssh/id_ed25519_np")
#       host        = each.value.address
#     }
#   }
# }
# create a cloud-init cloud-config.
# NB this creates an iso image that will be used by the NoCloud cloud-init datasource.
# see https://github.com/dmacvicar/terraform-provider-libvirt/blob/v0.7.1/website/docs/r/cloudinit.html.markdown
# see journactl -u cloud-init
# see /run/cloud-init/*.log
# see https://cloudinit.readthedocs.io/en/latest/topics/examples.html#disk-setup
# see https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html#datasource-nocloud
# see https://github.com/dmacvicar/terraform-provider-libvirt/blob/v0.7.1/libvirt/cloudinit_def.go#L133-L162
resource "libvirt_cloudinit_disk" "vm_init" {
  count     = var.vm_count
  name      = "${var.host_prefix}${local.vm_nodes[count.index].name}_cloudinit.iso"
  user_data = <<EOF
#cloud-config
fqdn: ${var.host_prefix}${local.vm_nodes[count.index].name}.${var.network_domain}
manage_etc_hosts: true
users:
  - name: ${var.admin_name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/${var.admin_name}
    shell: /bin/bash
    passwd: '${var.admin_password_hash}'
    lock_passwd: false
    ssh-authorized-keys:
      - ${jsonencode(trimspace(file("${var.path_to_ssh_public_key}")))}
  - name: root
    home: /root
    shell: /bin/bash
    passwd: '${var.admin_password_hash}'
    lock_passwd: false
    ssh-authorized-keys:
      - ${jsonencode(trimspace(file("${var.path_to_ssh_public_key}")))}
ssh_pwauth: True
runcmd:
  - [ bash, -c, 'echo "Cloud-init start: $(TZ=":America/Vancouver" date "+%Y-%m-%d %H:%M:%S.%N %Z")" >> /home/${var.admin_name}/cloud-init-run.log' ]
  - [ bash, -c, 'echo "Running: parted /dev/vdb --script -- mklabel gpt mkpart primary ext4 0% 100%" >> /home/${var.admin_name}/cloud-init-run.log; parted /dev/vdb --script -- mklabel gpt mkpart primary ext4 0% 100% >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Running: lsblk -f /dev/vdb1 --output FSTYPE" >> /home/${var.admin_name}/cloud-init-run.log; lsblk -f /dev/vdb1 --output FSTYPE | grep -q "^$" && echo "Running: mkfs.ext4 /dev/vdb1" >> /home/${var.admin_name}/cloud-init-run.log; mkfs.ext4 /dev/vdb1 >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Running: e2label /dev/vdb1 data" >> /home/${var.admin_name}/cloud-init-run.log; e2label /dev/vdb1 data >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Running: mkdir -p /data" >> /home/${var.admin_name}/cloud-init-run.log; mkdir -p /data >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Running: mount LABEL=data /data" >> /home/${var.admin_name}/cloud-init-run.log; mount LABEL=data /data >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Running: echo \"LABEL=data /data ext4 defaults 0 0\" >> /etc/fstab" >> /home/${var.admin_name}/cloud-init-run.log; echo "LABEL=data /data ext4 defaults 0 0" >> /etc/fstab' ]
  - [ bash, -c, 'start_time=$(TZ=":America/Vancouver" date "+%Y-%m-%d %H:%M:%S.%N %Z"); echo "Running Wget - install-rke2-worker.sh: $start_time" >> /home/${var.admin_name}/cloud-init-run.log' ]
  - [ bash, -c, 'wget -P /tmp https://raw.githubusercontent.com/bashfulrobot/libvirt-module-helpers/main/install-rke2-worker.sh >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'chmod +x /tmp/install-rke2-worker.sh >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, '/tmp/install-rke2-worker.sh >> /home/${var.admin_name}/cloud-init-run.log 2>&1' ]
  - [ bash, -c, 'echo "Cloud-init end: $(TZ=":America/Vancouver" date "+%Y-%m-%d %H:%M:%S.%N %Z")" >> /home/${var.admin_name}/cloud-init-run.log' ]
EOF
}

resource "libvirt_volume" "base-os-volume" {
  name   = "${var.cluster_name}-os"
  source = var.image_url
  format = "qcow2"
}

resource "libvirt_volume" "data" {
  count  = var.vm_count
  name   = "${var.host_prefix}${local.vm_nodes[count.index].name}-data"
  format = "qcow2"
  size   = var.vm_data_disk_size * 1024 * 1024 * 1024
}

# see https://github.com/dmacvicar/terraform-provider-libvirt/blob/v0.7.1/website/docs/r/volume.html.markdown
resource "libvirt_volume" "vm" {
  count          = var.vm_count
  name           = "${var.host_prefix}${local.vm_nodes[count.index].name}"
  base_volume_id = libvirt_volume.base-os-volume.id
  format         = "qcow2"
  size           = var.vm_os_disk_size * 1024 * 1024 * 1024 # 40GiB.
}

# see https://github.com/dmacvicar/terraform-provider-libvirt/blob/v0.7.1/website/docs/r/domain.html.markdown
resource "libvirt_domain" "vm" {
  count = var.vm_count
  name  = "${var.host_prefix}${local.vm_nodes[count.index].name}"
  # machine = "q35"
  cpu {
    mode = "host-passthrough"
  }
  vcpu       = var.vm_vcpu
  memory     = var.vm_memory * 1024
  autostart  = var.autostart
  qemu_agent = var.enable_qemu_agent
  cloudinit  = libvirt_cloudinit_disk.vm_init[count.index].id
  video {
    type = "qxl"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.vm[count.index].id
  }

  disk {
    volume_id = libvirt_volume.data[count.index].id
  }

  network_interface {
    network_id     = var.network_id
    wait_for_lease = var.wait_for_lease
    addresses      = [local.vm_nodes[count.index].address]
  }
}

output "workers" {
  value = [for node in local.vm_nodes : node.address]
}
