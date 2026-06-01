provider "aws" {
  region = "ap-southeast-1" # Chỉnh theo region bạn dùng
}

module "vpc" {
  source     = "./modules/vpc"
  name       = "travelweb-vpc"
  cidr_block = "10.0.0.0/16"
}

module "subnet" {
  source     = "./modules/subnet"
  name       = "travelweb-subnet"
  vpc_id     = module.vpc.vpc_id
  cidr_block = "10.0.1.0/24"
  az         = "ap-southeast-1a"
}

module "sg" {
  source      = "./modules/security_group"
  name        = "travelweb-sg"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 8080, to_port = 8080, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 9000, to_port = 9000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # SonarQube
  ]
  egress_rules = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  ]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = "main-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = module.vpc.vpc_id
  tags   = { Name = "main-public-rt" }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = module.subnet.subnet_id
  route_table_id = aws_route_table.public.id
}

module "ec2" {
  source                 = "./modules/EC2"
  name                   = "travelweb-ec2"
  ami_id                 = "ami-0a56f8447277affd8"
  instance_type          = "m7i-flex.large"
  subnet_id              = module.subnet.subnet_id
  key_name               = "jenkin_keypair"
  vpc_security_group_ids = [module.sg.sg_id]
  user_data              = file("${path.module}/user_data.sh")
}

output "ec2_public_ip" {
  value = module.ec2.public_ip
}
