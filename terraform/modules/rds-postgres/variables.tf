variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }

variable "db_name" { type = string }
variable "username" {
  type    = string
  default = "app"
}

variable "engine_version" {
  type    = string
  # Use a valid RDS engine version string; RDS will pick the latest revision (R1, R2, ...)
  default = "17.4"
}
variable "parameter_group_family" {
  type    = string
  default = "postgres17"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "max_allocated_storage" {
  type    = number
  default = 100
}
variable "storage_type" {
  type    = string
  default = "gp3"
}
variable "storage_throughput" {
  type    = number
  default = null
}

variable "multi_az" {
  type    = bool
  default = false
}
variable "publicly_accessible" {
  type    = bool
  default = false
}
variable "backup_retention" {
  type    = number
  default = 7
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "auto_minor_version_upgrade" {
  type    = bool
  default = true
}
variable "maintenance_window" {
  type    = string
  default = null
}
variable "backup_window" {
  type    = string
  default = null
}

variable "monitoring_interval" {
  type    = number
  default = 0
} # 0 disables enhanced monitoring
variable "performance_insights_enabled" {
  type    = bool
  default = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the DB"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the DB"
  type        = list(string)
  default     = []
}

variable "create_secret_manager" {
  type    = bool
  default = true
}
