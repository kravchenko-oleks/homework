provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2",
    ]
  }
}

locals {
  name = "demo-nginx"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  user_data = templatefile("templates/userdata.sh.tpl", {
    docker_image = "nginxdemos/hello"
  })
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]

}

module "autoscaling" {
  source = "../../modules/aws-autoscaling"

  name            = "autoscaling-${local.name}"
  use_name_prefix = false
  instance_name   = "my-instance-name"

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  vpc_zone_identifier     = module.vpc.public_subnets
  #service_linked_role_arn = aws_iam_service_linked_role.autoscaling.arn

  create_traffic_source_attachment = true
  traffic_source_type              = "elbv2"

  launch_template_name        = "autoscaling-${local.name}"
  update_default_version      = true
  image_id                    = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  user_data                   = base64encode(local.user_data)
  create_iam_instance_profile = true
  iam_role_name               = "autoscaling-${local.name}"
  iam_role_path               = "/ec2/"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp2"
      }
    }
  ]
  network_interfaces = [
    {
      associate_public_ip_address = true
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
    }
  ]

  placement = {
    availability_zone = "${var.region}b"
  }

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    }
  ]

  tags = var.tags

################################
#### ALB configuration #########
################################
  vpc_id   = module.vpc.vpc_id
  subnets  = module.vpc.public_subnets
  internal = var.internal_lb

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    ex_http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "ex_asg"
      }
    }
  }

  target_groups = {
    ex_asg = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "instance"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false
    }
  }

}