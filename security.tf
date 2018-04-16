# Vault specific Security Group
module "vault_service" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "vault-service"
  description = "vault services"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp", "consul-webui-tcp"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 8200
      to_port     = 8201
      protocol    = "tcp"
      description = "Vault-Server"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_rules = ["all-all"]
}

# Consul specific Security Group
module "consul_service" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "consul-service"
  description = "consul services"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["10.0.0.0/16"]
  ingress_rules       = ["consul-dns-tcp", "consul-dns-udp", "consul-serf-lan-tcp", "consul-serf-lan-udp", "consul-tcp"]

  egress_rules = ["all-all"]
}

module "mysql_service" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "mysql-service"
  description = "mysql services"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress_cidr_blocks = ["10.0.0.0/16", "0.0.0.0/0"]
  ingress_rules       = ["mysql-tcp"]

  egress_rules = ["all-all"]
}

provider "vault" {}

data "vault_aws_access_credentials" "aws_creds" {
  backend = "aws"
  role    = "azc-role"
}

provider "aws" {
  access_key = "${data.vault_aws_access_credentials.aws_creds.access_key}"
  secret_key = "${data.vault_aws_access_credentials.aws_creds.secret_key}"
  region     = "${var.region}"
}
