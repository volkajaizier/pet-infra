locals {
  cluster_sg_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_security_group" "node_sg" {
  name        = "${var.name}-node-sg"
  description = "EKS worker nodes"
  vpc_id      = var.vpc_id

  # Internal traffic between nodes/podes inside VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # External traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-node-sg" }
}

# Control plane -> kubelet 
resource "aws_security_group_rule" "cplane_to_nodes_kubelet" {
  type                     = "ingress"
  description              = "Control plane to nodes (kubelet 10250)"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_sg.id
  source_security_group_id = local.cluster_sg_id
}

# Nodes -> API server (443/tcp) on Cluster SG
resource "aws_security_group_rule" "nodes_to_cplane_api" {
  type                     = "ingress"
  description              = "Nodes to API server (443)"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = local.cluster_sg_id
  source_security_group_id = aws_security_group.node_sg.id
}

output "node_sg_id" {
  value       = aws_security_group.node_sg.id
  description = "Security Group ID for EKS worker nodes"
}