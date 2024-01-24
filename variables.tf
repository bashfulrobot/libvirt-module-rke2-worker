variable "admin_name" {
  type    = string
  default = "admin"
}

variable "admin_password_hash" {
  type = string
}

variable "path_to_ssh_public_key" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}
variable "host_prefix" {
  type    = string
  default = "vm"
}

variable "host_suffix" {
  type    = string
  default = ""
}

variable "vm_count" {
  description = "The number of VMs to deploy"
  type        = number
  default     = 1
  validation {
    condition     = var.vm_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "kvm_subnet_prefix" {
  type    = string
  default = "null"
  validation {
    condition     = var.kvm_subnet_prefix != "null" && can(regex("^([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3})$", var.kvm_subnet_prefix))
    error_message = "The kvm_subnet_prefix must be in the form of \"x.x.x\", where each x is a number between 0 and 255, and match that of the network you are deploying to."
  }
}

variable "network_domain" {
  description = "The domain name for the k8s cluster network"
  type        = string
  default     = "local"
}

variable "network_id" {
  description = "The ID of the network to deploy to"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "A name to provide for the k8s cluster"
  type        = string
  default     = "dk-cluster"
}

variable "vm_vcpu" {
  description = "The number of virtual CPUs for the vm nodes"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "The amount of memory in GB for the vm nodes"
  type        = number
  default     = 2
}

variable "vm_os_disk_size" {
  description = "The size of the OS disk in GB for the vm nodes"
  type        = number
  default     = 60
}

variable "vm_data_disk_size" {
  description = "The size of the data disk in GB for the vm nodes"
  type        = number
  default     = 100
}

variable "image_url" {
  description = "The URL of the image used to deploy the VMs"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "autostart" {
  description = "Whether to automatically start the VMs"
  type        = bool
  default     = false
}

variable "enable_qemu_agent" {
  description = "Whether to enable the qemu agent"
  type        = bool
  default     = false
}

variable "wait_for_lease" {
  description = "Whether to wait for the DHCP lease to be assigned"
  type        = bool
  default     = false
}

# variable "node_type" {
#   description = "The type of node to deploy"
#   type        = string
#   default     = "vm_only"

#   validation {
#     condition     = anytrue([for v in ["k8s_vm", "k8s_worker", "k8s_single_node", "vm_only", "vm_only_2disk"] : var.node_type == v])
#     error_message = "The node_type must be one of: k8s_vm, k8s_worker, k8s_single_node, vm_only, or vm_only_2disk"
#   }
# }
