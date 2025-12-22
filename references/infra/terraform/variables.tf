variable "region" { type = string }
variable "name_prefix" { type = string }

variable "orders_image" {
  description = "ECR image URI for orders-service (e.g., 123.dkr.ecr.us-east-1.amazonaws.com/orders:sha)"
  type        = string
  default     = ""
}

variable "inventory_image" {
  description = "ECR image URI for inventory-service"
  type        = string
  default     = ""
}

variable "payments_image" {
  description = "ECR image URI for payments-service"
  type        = string
  default     = ""
}

variable "desired_count" {
  type    = number
  default = 1
}
