variable "vpc_cidr" {
  description = "CIDR range for VPC"
  default     = "10.0.0.0/16"
}

variable "region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "env" {
  description = "Environment"
  default     = "dev"
}

variable "tags" {
  type        = map(any)
  description = "A map of tags to add to all resources"
}

variable "instance_type" {
  description = "The type of the instance."
  type        = string
  default     = "t2.micro"
}

variable "internal_lb" {
  description = "If true, the LB will be internal. Defaults to `false`"
  type        = bool
  default     = null
}

variable "min_size" {
  description = "The minimum size of the autoscaling group"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "The maximum size of the autoscaling group"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the autoscaling group"
  type        = number
  default     = 1
}