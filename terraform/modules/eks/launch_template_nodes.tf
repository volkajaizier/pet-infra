variable "lt_name_prefix" {
  type        = string
  description = "Prefix for EKS nodes Launch Template"
  default     = "eks-ng-"
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GiB for worker nodes"
  default     = 40
}

variable "node_additional_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags for node instances"
}

resource "aws_launch_template" "nodes" {
  name_prefix            = "${var.name}-${var.lt_name_prefix}"
  update_default_version = true

  network_interfaces {
    security_groups = [aws_security_group.node_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      "Name"      = "${var.name}-node"
      "Cluster"   = var.name
      "Component" = "eks-node"
    }, var.node_additional_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      "Name"      = "${var.name}-node-volume"
      "Cluster"   = var.name
      "Component" = "eks-node"
    }, var.node_additional_tags)
  }
}

