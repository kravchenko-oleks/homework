region   = "eu-west-1"
vpc_cidr = "10.0.0.0/16"

env = "Dev"

tags = {
  Charge_Code               = "12345"
  Service_Owner             = "TEAM_NAME"
  Orchestration             = "TF"
  finops_billing_code       = "yqk51"
  Environment               = "DEV"
}

instance_type = "t2.micro"
max_size      = 3
desired_capacity = 1