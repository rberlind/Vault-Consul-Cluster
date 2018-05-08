data "terraform_remote_state" "primary_vault" {
  count   = "${var.cluster == "Secondary" ? 1 : 0}"
  backend = "atlas"

  config {
    name = "azc/${var.primary_workspace}"
  }
}

provider "aws" {
  alias      = "peer"
  region     = "us-east-2"
  access_key = "${data.vault_generic_secret.aws_stuff.data["access_key"]}"
  secret_key = "${data.vault_generic_secret.aws_stuff.data["secret_key"]}"

  # Accepter's credentials.
}

data "aws_caller_identity" "peer" {
  count    = "${var.cluster == "Secondary" ? 1 : 0}"
  provider = "aws.peer"
}

# Requester's side of the connection.
resource "aws_vpc_peering_connection" "peer" {
  count         = "${var.cluster == "Secondary" ? 1 : 0}"
  vpc_id        = "${module.vpc.vpc_id}"
  peer_vpc_id   = "${data.terraform_remote_state.primary_vault.vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.peer.account_id}"
  peer_region   = "us-east-2"
  auto_accept   = false

  tags {
    Side = "Requester"
  }
}

# Accepter's side of the connection.
resource "aws_vpc_peering_connection_accepter" "peer" {
  count                     = "${var.cluster == "Secondary" ? 1 : 0}"
  provider                  = "aws.peer"
  vpc_peering_connection_id = "${aws_vpc_peering_connection.peer.id}"
  auto_accept               = true

  tags {
    Side = "Accepter"
  }
}

####Create Necessary Routes 
data "aws_vpc_peering_connection" "primaryvpc" {
  count           = "${var.cluster == "Secondary" ? 1 : 0}"
  vpc_id          = "${data.terraform_remote_state.primary_vault.vpc_id}"
  peer_cidr_block = "10.0.0.0/16"
}

data "aws_vpc_peering_connection" "secondaryvpc" {
  count           = "${var.cluster == "Secondary" ? 1 : 0}"
  vpc_id          = "${module.vpc.vpc_id}"
  peer_cidr_block = "10.1.0.0/16"
}

# Create a route table
resource "aws_route_table" "rt-p" {
  count  = "${var.cluster == "Secondary" ? 1 : 0}"
  vpc_id = "${data.terraform_remote_state.primary_vault.vpc_id}"
}

resource "aws_route_table" "rt-s" {
  count  = "${var.cluster == "Secondary" ? 1 : 0}"
  vpc_id = "${module.vpc.vpc_id}"
}

# Create a route
resource "aws_route" "r" {
  count                     = "${var.cluster == "Secondary" ? 1 : 0}"
  route_table_id            = "${aws_route_table.rt-p.id}"
  destination_cidr_block    = "${data.aws_vpc_peering_connection.primaryvpc.peer_cidr_block}"
  vpc_peering_connection_id = "${data.aws_vpc_peering_connection.primaryvpc.id}"
}

resource "aws_route" "r" {
  count                     = "${var.cluster == "Secondary" ? 1 : 0}"
  route_table_id            = "${aws_route_table.rt-s.id}"
  destination_cidr_block    = "${data.aws_vpc_peering_connection.secondaryvpc.peer_cidr_block}"
  vpc_peering_connection_id = "${data.aws_vpc_peering_connection.secondaryvpc.id}"
}