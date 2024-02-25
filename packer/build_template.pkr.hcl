# Packer Template to create VM Template on Proxmox
packer {
  required_plugins {
    name = {
      version = "~> 1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox_api_url" {
    type = string
    default = "https://192.168.30.2:8006/api2/json"
}

variable "proxmox_api_token_id" {
    type = string
    default = "root@pam!packer"
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

# Resource Definiation for the VM Template
source "proxmox-iso" "k8s-template" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true

    # VM General Settings
    node = "proxmox"
    vm_id = "800"
    vm_name = "K8s-template"
    template_description = "Template prepared for K8s deployment"

    # VM OS Settings
    iso_storage_pool = "local"
    iso_url = "https://releases.ubuntu.com/23.10/ubuntu-23.10-live-server-amd64.iso"
    iso_checksum = "d2fb80d9ce77511ed500bcc1f813e6f676d4a3577009dfebce24269ca23346a5"

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "10G"
        format = "raw"
        storage_pool = "lvm-local"
        type = "virtio"
    }

    # VM CPU Settings
    sockets = 2
    cores = 2
    cpu_type = "host"
    os = "l26"

    # VM Memory Settings
    memory = "6144"

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    }

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "lvm-local"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait10>",
        "e<wait10>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><wait>",
        "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
        "<f10><wait>"
    ]
    // boot = "virtio0"
    boot_wait = "5s"
    unmount_iso = true

    # PACKER Autoinstall Settings
    http_directory = "packer/http"
    # (Optional) Bind IP Address and Port
    // http_bind_address = "192.168.30.167"
    // http_port_min = 8802
    // http_port_max = 8802

    ssh_username = "sergei"



    # Raise the timeout, when installation takes longer
    ssh_timeout = "20m"
}

# Build Definition to create the VM Template
build {

    name = "k8s-template"
    sources = ["proxmox-iso.k8s-template"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo rm -f /etc/netplan/00-installer-config.yaml",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "packer/files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Add additional provisioning scripts here
    # ...
}