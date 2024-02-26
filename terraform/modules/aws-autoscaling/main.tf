data "aws_partition" "current" {}

locals {
  create                  = var.create
  launch_template_name    = coalesce(var.launch_template_name, var.name)
  launch_template_id      = var.create_launch_template ? aws_launch_template.this[0].id : var.launch_template_id
  launch_template_version = var.create_launch_template && var.launch_template_version == null ? aws_launch_template.this[0].latest_version : var.launch_template_version

  asg_tags = merge(
    var.tags,
    { "Name" = coalesce(var.instance_name, var.name) },
    var.autoscaling_group_tags,
  )
}

################################################################################
# Launch template
################################################################################

locals {
  iam_instance_profile_arn  = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].arn : var.iam_instance_profile_arn
  iam_instance_profile_name = !var.create_iam_instance_profile && var.iam_instance_profile_arn == null ? var.iam_instance_profile_name : null
}

resource "aws_launch_template" "this" {
  count = var.create_launch_template ? 1 : 0

  name        = var.launch_template_use_name_prefix ? null : local.launch_template_name
  name_prefix = var.launch_template_use_name_prefix ? "${local.launch_template_name}-" : null
  description = var.launch_template_description

  ebs_optimized = var.ebs_optimized
  image_id      = var.image_id
  key_name      = var.key_name
  user_data     = var.user_data

  vpc_security_group_ids = length(var.network_interfaces) > 0 ? [] : var.security_groups

  default_version                      = var.default_version
  update_default_version               = var.update_default_version
  disable_api_termination              = var.disable_api_termination
  disable_api_stop                     = var.disable_api_stop
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior
  kernel_id                            = var.kernel_id
  ram_disk_id                          = var.ram_disk_id

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name  = block_device_mappings.value.device_name
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)

      dynamic "ebs" {
        for_each = flatten([try(block_device_mappings.value.ebs, [])])
        content {
          delete_on_termination = try(ebs.value.delete_on_termination, null)
          encrypted             = try(ebs.value.encrypted, null)
          kms_key_id            = try(ebs.value.kms_key_id, null)
          iops                  = try(ebs.value.iops, null)
          throughput            = try(ebs.value.throughput, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }
    }
  }

  dynamic "iam_instance_profile" {
    for_each = local.iam_instance_profile_name != null || local.iam_instance_profile_arn != null ? [1] : []
    content {
      name = local.iam_instance_profile_name
      arn  = local.iam_instance_profile_arn
    }
  }

  instance_type = var.instance_type


  dynamic "monitoring" {
    for_each = var.enable_monitoring ? [1] : []
    content {
      enabled = var.enable_monitoring
    }
  }

  dynamic "network_interfaces" {
    for_each = var.network_interfaces
    content {
      associate_carrier_ip_address = try(network_interfaces.value.associate_carrier_ip_address, null)
      associate_public_ip_address  = try(network_interfaces.value.associate_public_ip_address, null)
      delete_on_termination        = try(network_interfaces.value.delete_on_termination, null)
      description                  = try(network_interfaces.value.description, null)
      device_index                 = try(network_interfaces.value.device_index, null)
      interface_type               = try(network_interfaces.value.interface_type, null)
      ipv4_prefix_count            = try(network_interfaces.value.ipv4_prefix_count, null)
      ipv4_prefixes                = try(network_interfaces.value.ipv4_prefixes, null)
      ipv4_addresses               = try(network_interfaces.value.ipv4_addresses, [])
      ipv4_address_count           = try(network_interfaces.value.ipv4_address_count, null)
      network_interface_id         = try(network_interfaces.value.network_interface_id, null)
      network_card_index           = try(network_interfaces.value.network_card_index, null)
      private_ip_address           = try(network_interfaces.value.private_ip_address, null)
      # Ref: https://github.com/hashicorp/terraform-provider-aws/issues/4570
      security_groups = [aws_security_group.asg.id]
      subnet_id       = try(network_interfaces.value.subnet_id, null)
    }
  }

  dynamic "placement" {
    for_each = length(var.placement) > 0 ? [var.placement] : []
    content {
      affinity                = try(placement.value.affinity, null)
      availability_zone       = try(placement.value.availability_zone, null)
      group_name              = try(placement.value.group_name, null)
      host_id                 = try(placement.value.host_id, null)
      host_resource_group_arn = try(placement.value.host_resource_group_arn, null)
      spread_domain           = try(placement.value.spread_domain, null)
      tenancy                 = try(placement.value.tenancy, null)
      partition_number        = try(placement.value.partition_number, null)
    }
  }

  dynamic "tag_specifications" {
    for_each = var.tag_specifications
    content {
      resource_type = tag_specifications.value.resource_type
      tags          = merge(var.tags, tag_specifications.value.tags)
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags       = var.tags
  depends_on = [aws_security_group.asg]
}

resource "aws_security_group" "asg" {
  name_prefix = var.use_name_prefix ? "${var.name}-" : null
  description = var.security_group_description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, var.security_group_tags)

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_security_group_rule" "ingress_rules" {

  security_group_id = aws_security_group.asg.id
  type              = "ingress"

  source_security_group_id = aws_security_group.this[0].id

  from_port = "80"
  to_port   = "80"

  protocol = "tcp"
}

resource "aws_security_group_rule" "egress_rules" {

  security_group_id = aws_security_group.asg.id
  type              = "egress"
  cidr_blocks       = var.egress_cidr_blocks
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
}

################################################################################
# Autoscaling group 
################################################################################

resource "aws_autoscaling_group" "this" {
  count = local.create ? 1 : 0

  name        = var.use_name_prefix ? null : var.name
  name_prefix = var.use_name_prefix ? "${var.name}-" : null

  dynamic "launch_template" {
    for_each = var.use_mixed_instances_policy ? [] : [1]

    content {
      id      = local.launch_template_id
      version = local.launch_template_version
    }
  }

  availability_zones  = var.availability_zones
  vpc_zone_identifier = var.vpc_zone_identifier

  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  desired_capacity_type     = var.desired_capacity_type
  capacity_rebalance        = var.capacity_rebalance
  min_elb_capacity          = var.min_elb_capacity
  wait_for_elb_capacity     = var.wait_for_elb_capacity
  wait_for_capacity_timeout = var.wait_for_capacity_timeout
  default_cooldown          = var.default_cooldown
  default_instance_warmup   = var.default_instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in

  # TODO - remove at next breaking change. Use `traffic_source_identifier`/`traffic_source_type` instead
  load_balancers = var.load_balancers
  # TODO - remove at next breaking change. Use `traffic_source_identifier`/`traffic_source_type` instead
  target_group_arns         = var.target_group_arns
  placement_group           = var.placement_group
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  force_delete          = var.force_delete
  termination_policies  = var.termination_policies
  suspended_processes   = var.suspended_processes
  max_instance_lifetime = var.max_instance_lifetime

  enabled_metrics                  = var.enabled_metrics
  metrics_granularity              = var.metrics_granularity
  service_linked_role_arn          = var.service_linked_role_arn

  dynamic "initial_lifecycle_hook" {
    for_each = var.initial_lifecycle_hooks
    content {
      name                    = initial_lifecycle_hook.value.name
      default_result          = try(initial_lifecycle_hook.value.default_result, null)
      heartbeat_timeout       = try(initial_lifecycle_hook.value.heartbeat_timeout, null)
      lifecycle_transition    = initial_lifecycle_hook.value.lifecycle_transition
      notification_metadata   = try(initial_lifecycle_hook.value.notification_metadata, null)
      notification_target_arn = try(initial_lifecycle_hook.value.notification_target_arn, null)
      role_arn                = try(initial_lifecycle_hook.value.role_arn, null)
    }
  }

  dynamic "instance_maintenance_policy" {
    for_each = length(var.instance_maintenance_policy) > 0 ? [var.instance_maintenance_policy] : []
    content {
      min_healthy_percentage = instance_maintenance_policy.value.min_healthy_percentage
      max_healthy_percentage = instance_maintenance_policy.value.max_healthy_percentage
    }
  }

  timeouts {
    delete = var.delete_timeout
  }

  dynamic "tag" {
    for_each = local.asg_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  /*
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      load_balancers,
      target_group_arns,
    ]name
  }
  */
}


resource "aws_autoscaling_traffic_source_attachment" "this" {
  count = local.create && var.create_traffic_source_attachment ? 1 : 0

  autoscaling_group_name = aws_autoscaling_group.this[0].id

  traffic_source {
    identifier = aws_lb_target_group.this["ex_asg"].arn
    type       = var.traffic_source_type
  }
}

locals {
  internal_iam_instance_profile_name = try(coalesce(var.iam_instance_profile_name, var.iam_role_name), "")
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  statement {
    sid     = "EC2AssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.internal_iam_instance_profile_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.internal_iam_instance_profile_name}-" : null
  path        = var.iam_role_path
  description = var.iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary  = var.iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = { for k, v in var.iam_role_policies : k => v if var.create && var.create_iam_instance_profile }

  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_instance_profile" "this" {
  count = local.create && var.create_iam_instance_profile ? 1 : 0

  role = aws_iam_role.this[0].name

  name        = var.iam_role_use_name_prefix ? null : var.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${var.iam_role_name}-" : null
  path        = var.iam_role_path

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_lb" "this" {
  count = local.create ? 1 : 0

  dynamic "access_logs" {
    for_each = length(var.access_logs) > 0 ? [var.access_logs] : []

    content {
      bucket  = access_logs.value.bucket
      enabled = try(access_logs.value.enabled, true)
      prefix  = try(access_logs.value.prefix, null)
    }
  }


  customer_owned_ipv4_pool                    = var.customer_owned_ipv4_pool
  desync_mitigation_mode                      = var.desync_mitigation_mode
  drop_invalid_header_fields                  = var.drop_invalid_header_fields
  enable_cross_zone_load_balancing            = var.enable_cross_zone_load_balancing
  enable_http2                                = var.enable_http2
  enable_tls_version_and_cipher_suite_headers = var.enable_tls_version_and_cipher_suite_headers
  enable_waf_fail_open                        = var.enable_waf_fail_open
  enable_xff_client_port                      = var.enable_xff_client_port
  idle_timeout                                = var.idle_timeout
  internal                                    = var.internal
  ip_address_type                             = var.ip_address_type
  load_balancer_type                          = var.load_balancer_type
  name                                        = var.name
  name_prefix                                 = var.name_prefix
  preserve_host_header                        = var.preserve_host_header
  security_groups                             = var.create_security_group ? concat([aws_security_group.this[0].id], var.security_groups) : var.security_groups

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping

    content {
      allocation_id        = lookup(subnet_mapping.value, "allocation_id", null)
      ipv6_address         = lookup(subnet_mapping.value, "ipv6_address", null)
      private_ipv4_address = lookup(subnet_mapping.value, "private_ipv4_address", null)
      subnet_id            = subnet_mapping.value.subnet_id
    }
  }

  subnets                    = var.subnets
  tags                       = var.tags
  xff_header_processing_mode = var.xff_header_processing_mode

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }

  lifecycle {
    ignore_changes = [
      tags["elasticbeanstalk:shared-elb-environment-count"]
    ]
  }
}

################################################################################
# Listener(s)
################################################################################

resource "aws_lb_listener" "this" {
  for_each = { for k, v in var.listeners : k => v if local.create }

  alpn_policy     = try(each.value.alpn_policy, null)
  certificate_arn = try(each.value.certificate_arn, null)

  dynamic "default_action" {
    for_each = try([each.value.authenticate_cognito], [])

    content {
      authenticate_cognito {
        authentication_request_extra_params = try(default_action.value.authentication_request_extra_params, null)
        on_unauthenticated_request          = try(default_action.value.on_unauthenticated_request, null)
        scope                               = try(default_action.value.scope, null)
        session_cookie_name                 = try(default_action.value.session_cookie_name, null)
        session_timeout                     = try(default_action.value.session_timeout, null)
        user_pool_arn                       = default_action.value.user_pool_arn
        user_pool_client_id                 = default_action.value.user_pool_client_id
        user_pool_domain                    = default_action.value.user_pool_domain
      }

      order = try(default_action.value.order, null)
      type  = "authenticate-cognito"
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.authenticate_oidc], [])

    content {
      authenticate_oidc {
        authentication_request_extra_params = try(default_action.value.authentication_request_extra_params, null)
        authorization_endpoint              = default_action.value.authorization_endpoint
        client_id                           = default_action.value.client_id
        client_secret                       = default_action.value.client_secret
        issuer                              = default_action.value.issuer
        on_unauthenticated_request          = try(default_action.value.on_unauthenticated_request, null)
        scope                               = try(default_action.value.scope, null)
        session_cookie_name                 = try(default_action.value.session_cookie_name, null)
        session_timeout                     = try(default_action.value.session_timeout, null)
        token_endpoint                      = default_action.value.token_endpoint
        user_info_endpoint                  = default_action.value.user_info_endpoint
      }

      order = try(default_action.value.order, null)
      type  = "authenticate-oidc"
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.fixed_response], [])

    content {
      fixed_response {
        content_type = default_action.value.content_type
        message_body = try(default_action.value.message_body, null)
        status_code  = try(default_action.value.status_code, null)
      }

      order = try(default_action.value.order, null)
      type  = "fixed-response"
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.forward], [])

    content {
      order            = try(default_action.value.order, null)
      target_group_arn = length(try(default_action.value.target_groups, [])) > 0 ? null : try(default_action.value.arn, aws_lb_target_group.this[default_action.value.target_group_key].arn, null)
      type             = "forward"
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.weighted_forward], [])

    content {
      forward {
        dynamic "target_group" {
          for_each = try(default_action.value.target_groups, [])

          content {
            arn    = try(target_group.value.arn, aws_lb_target_group.this[target_group.value.target_group_key].arn, null)
            weight = try(target_group.value.weight, null)
          }
        }

        dynamic "stickiness" {
          for_each = try([default_action.value.stickiness], [])

          content {
            duration = try(stickiness.value.duration, 60)
            enabled  = try(stickiness.value.enabled, null)
          }
        }
      }

      order = try(default_action.value.order, null)
      type  = "forward"
    }
  }

  dynamic "default_action" {
    for_each = try([each.value.redirect], [])

    content {
      order = try(default_action.value.order, null)

      redirect {
        host        = try(default_action.value.host, null)
        path        = try(default_action.value.path, null)
        port        = try(default_action.value.port, null)
        protocol    = try(default_action.value.protocol, null)
        query       = try(default_action.value.query, null)
        status_code = default_action.value.status_code
      }

      type = "redirect"
    }
  }

  dynamic "mutual_authentication" {
    for_each = try([each.value.mutual_authentication], [])
    content {
      mode                             = mutual_authentication.value.mode
      trust_store_arn                  = try(mutual_authentication.value.trust_store_arn, null)
      ignore_client_certificate_expiry = try(mutual_authentication.value.ignore_client_certificate_expiry, null)
    }
  }

  load_balancer_arn = aws_lb.this[0].arn
  port              = try(each.value.port, var.default_port)
  protocol          = try(each.value.protocol, var.default_protocol)
  ssl_policy        = contains(["HTTPS", "TLS"], try(each.value.protocol, var.default_protocol)) ? try(each.value.ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Res-2021-06") : try(each.value.ssl_policy, null)
  tags              = merge(var.tags, try(each.value.tags, {}))
}


################################################################################
# Target Group(s)
################################################################################

resource "aws_lb_target_group" "this" {
  for_each = { for k, v in var.target_groups : k => v if local.create }

  connection_termination = try(each.value.connection_termination, null)
  deregistration_delay   = try(each.value.deregistration_delay, null)

  dynamic "health_check" {
    for_each = try([each.value.health_check], [])

    content {
      enabled             = try(health_check.value.enabled, null)
      healthy_threshold   = try(health_check.value.healthy_threshold, null)
      interval            = try(health_check.value.interval, null)
      matcher             = try(health_check.value.matcher, null)
      path                = try(health_check.value.path, null)
      port                = try(health_check.value.port, null)
      protocol            = try(health_check.value.protocol, null)
      timeout             = try(health_check.value.timeout, null)
      unhealthy_threshold = try(health_check.value.unhealthy_threshold, null)
    }
  }

  ip_address_type                    = try(each.value.ip_address_type, null)
  lambda_multi_value_headers_enabled = try(each.value.lambda_multi_value_headers_enabled, null)
  load_balancing_algorithm_type      = try(each.value.load_balancing_algorithm_type, null)
  load_balancing_cross_zone_enabled  = try(each.value.load_balancing_cross_zone_enabled, null)
  name                               = try(each.value.name, null)
  name_prefix                        = try(each.value.name_prefix, null)
  port                               = try(each.value.target_type, null) == "lambda" ? null : try(each.value.port, var.default_port)
  preserve_client_ip                 = try(each.value.preserve_client_ip, null)
  protocol                           = try(each.value.target_type, null) == "lambda" ? null : try(each.value.protocol, var.default_protocol)
  protocol_version                   = try(each.value.protocol_version, null)
  proxy_protocol_v2                  = try(each.value.proxy_protocol_v2, null)
  slow_start                         = try(each.value.slow_start, null)

  dynamic "stickiness" {
    for_each = try([each.value.stickiness], [])

    content {
      cookie_duration = try(stickiness.value.cookie_duration, null)
      cookie_name     = try(stickiness.value.cookie_name, null)
      enabled         = try(stickiness.value.enabled, true)
      type            = var.load_balancer_type == "network" ? "source_ip" : stickiness.value.type
    }
  }


  target_type = try(each.value.target_type, null)
  vpc_id      = try(each.value.vpc_id, var.vpc_id)

  tags = merge(var.tags, try(each.value.tags, {}))

  lifecycle {
    create_before_destroy = true
  }
}


################################################################################
# Security Group
################################################################################

locals {
  create_security_group = local.create && var.create_security_group
  security_group_name   = try(coalesce(var.security_group_name, var.name, var.name_prefix), "")
}

resource "aws_security_group" "this" {
  count = local.create_security_group ? 1 : 0

  name        = var.security_group_use_name_prefix ? null : local.security_group_name
  name_prefix = var.security_group_use_name_prefix ? "${local.security_group_name}-" : null
  description = coalesce(var.security_group_description, "Security group for ${local.security_group_name} ${var.load_balancer_type} load balancer")
  vpc_id      = var.vpc_id

  tags = merge(var.tags, var.security_group_tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for k, v in var.security_group_egress_rules : k => v if local.create_security_group }

  # Required
  security_group_id = aws_security_group.this[0].id
  ip_protocol       = try(each.value.ip_protocol, "tcp")

  # Optional
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  description                  = try(each.value.description, null)
  from_port                    = try(each.value.from_port, null)
  prefix_list_id               = lookup(each.value, "prefix_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  to_port                      = try(each.value.to_port, null)

  tags = merge(var.tags, var.security_group_tags, try(each.value.tags, {}))
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for k, v in var.security_group_ingress_rules : k => v if local.create_security_group }

  # Required
  security_group_id = aws_security_group.this[0].id
  ip_protocol       = try(each.value.ip_protocol, "tcp")

  # Optional
  cidr_ipv4                    = lookup(each.value, "cidr_ipv4", null)
  cidr_ipv6                    = lookup(each.value, "cidr_ipv6", null)
  description                  = try(each.value.description, null)
  from_port                    = try(each.value.from_port, null)
  prefix_list_id               = lookup(each.value, "prefix_list_id", null)
  referenced_security_group_id = lookup(each.value, "referenced_security_group_id", null)
  to_port                      = try(each.value.to_port, null)

  tags = merge(var.tags, var.security_group_tags, try(each.value.tags, {}))
}
