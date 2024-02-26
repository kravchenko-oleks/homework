output "autoscaling_launch_template_id" {
  description = "The ID of the launch template"
  value       = module.autoscaling.launch_template_id
}

output "autoscaling_launch_template_arn" {
  description = "The ARN of the launch template"
  value       = module.autoscaling.launch_template_arn
}

output "autoscaling_launch_template_name" {
  description = "The name of the launch template"
  value       = module.autoscaling.launch_template_name
}

output "autoscaling_launch_template_latest_version" {
  description = "The latest version of the launch template"
  value       = module.autoscaling.launch_template_latest_version
}

output "autoscaling_launch_template_default_version" {
  description = "The default version of the launch template"
  value       = module.autoscaling.launch_template_default_version
}

output "autoscaling_autoscaling_group_id" {
  description = "The autoscaling group id"
  value       = module.autoscaling.autoscaling_group_id
}

output "autoscaling_autoscaling_group_name" {
  description = "The autoscaling group name"
  value       = module.autoscaling.autoscaling_group_name
}

output "autoscaling_autoscaling_group_arn" {
  description = "The ARN for this AutoScaling Group"
  value       = module.autoscaling.autoscaling_group_arn
}

output "autoscaling_autoscaling_group_min_size" {
  description = "The minimum size of the autoscale group"
  value       = module.autoscaling.autoscaling_group_min_size
}

output "autoscaling_autoscaling_group_max_size" {
  description = "The maximum size of the autoscale group"
  value       = module.autoscaling.autoscaling_group_max_size
}

output "autoscaling_autoscaling_group_desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the group"
  value       = module.autoscaling.autoscaling_group_desired_capacity
}


output "load_balancer_id" {
  description = "The ID and ARN of the load balancer we created"
  value       = module.autoscaling.id
}

output "load_balancer_arn" {
  description = "The ID and ARN of the load balancer we created"
  value       = module.autoscaling.arn
}

output "load_balancer_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.autoscaling.dns_name
}
