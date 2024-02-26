region   = "eu-west-1"
vpc_cidr = "10.0.0.0/16"

env = "Prod"

tags = {
  Charge_Code               = "54321"
  Service_Owner             = "TEAM_NAME"
  Orchestration             = "TF"
  finops_billing_code       = "ds56d"
  Environment               = "PROD"
}

instance_type = "t3.micro"
max_size      = 4
desired_capacity = 3