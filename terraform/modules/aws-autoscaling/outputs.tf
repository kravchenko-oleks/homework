################################################################################
# Launch template
################################################################################

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = try(aws_launch_template.this[0].id, null)
}

output "launch_template_arn" {
  description = "The ARN of the launch template"
  value       = try(aws_launch_template.this[0].arn, null)
}

output "launch_template_name" {
  description = "The name of the launch template"
  value       = try(aws_launch_template.this[0].name, null)
}

output "launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = try(aws_launch_template.this[0].latest_version, null)
}

output "launch_template_default_version" {
  description = "The default version of the launch template"
  value       = try(aws_launch_template.this[0].default_version, null)
}

################################################################################
# Autoscaling group
################################################################################

output "autoscaling_group_id" {
  description = "The autoscaling group id"
  value       = try(aws_autoscaling_group.this[0].id, null)
}

output "autoscaling_group_name" {
  description = "The autoscaling group name"
  value       = try(aws_autoscaling_group.this[0].name, null)
}

output "autoscaling_group_arn" {
  description = "The ARN for this AutoScaling Group"
  value       = try(aws_autoscaling_group.this[0].arn, null)
}

output "autoscaling_group_min_size" {
  description = "The minimum size of the autoscale group"
  value       = try(aws_autoscaling_group.this[0].min_size, null)
}

output "autoscaling_group_max_size" {
  description = "The maximum size of the autoscale group"
  value       = try(aws_autoscaling_group.this[0].max_size, null)
}

output "autoscaling_group_desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the group"
  value       = try(aws_autoscaling_group.this[0].desired_capacity, null)
}

################################################################################
# Load Balancer
################################################################################

output "id" {
  description = "The ID and ARN of the load balancer we created"
  value       = try(aws_lb.this[0].id, null)
}

output "arn" {
  description = "The ID and ARN of the load balancer we created"
  value       = try(aws_lb.this[0].arn, null)
}

output "dns_name" {
  description = "The DNS name of the load balancer"
  value       = try(aws_lb.this[0].dns_name, null)
}
