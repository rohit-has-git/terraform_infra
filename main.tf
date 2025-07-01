terraform {
    backend "s3" {
        bucket = "todayrobu"
        key = "terraform.tfstate"
        region = "us-west-1"
    }
}

provider "aws" {
    region = "us-west-1"
}


data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "main-vpc"
    }

}

resource "aws_vpc_dhcp_options" "dns" {
    domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "main" {
    vpc_id = aws_vpc.main.id
    dhcp_options_id = aws_vpc_dhcp_options.dns.id
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_1" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_1
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true
}
resource "aws_subnet" "public_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_2
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true
}
resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_1
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = false
}
resource "aws_subnet" "private_2" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_2
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = false
}

resource "aws_eip" "nat" {
    domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public_1.id
    depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
}
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
}

resource "aws_route" "private_route" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "public_1" {
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
    subnet_id = aws_subnet.public_2.id
    route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_1" {
    subnet_id = aws_subnet.private_1.id
    route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_2" {
    subnet_id = aws_subnet.private_2.id
    route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "eks_nodes" {
    name = "gle-uvh-vam"
    description = "Security group for EKS nodes"
    vpc_id = aws_vpc.main.id
    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

module "eks" {
    source = "terraform-aws-modules/eks/aws"
    cluster_name = "wlv-mhlt"
    cluster_version = "1.29"
    cluster_endpoint_public_access = true
    vpc_id = aws_vpc.main.id
    subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

    eks_managed_node_groups = {
        default = {
            instance_type =  "t3.medium"
            desired_capacity = 2
            min_size = 1
            max_size = 2
            key_name = "akey"
            ami_type = "AL2_x86_64"
        }
    }


}









