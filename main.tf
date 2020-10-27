provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
data "aws_ami" "dynamic" {                              #data block provide filters to dynamically obtain AMI from packer build.
  #executable_users = ["self"]
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["packer-ami"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
resource "aws_launch_configuration" "patra-corp" {
  name_prefix   = "patra"
  image_id      = data.aws_ami.dynamic.id      #Dynamically obtain AMI ID from Packer build
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_inbound.id]  
  key_name = aws_key_pair.deployer.key_name
}
resource "aws_autoscaling_group" "patra-AG" {
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1
  launch_configuration = aws_launch_configuration.patra-corp.id
}
resource "aws_autoscaling_policy" "patra" {
   name                   = "scaling_policy"
   scaling_adjustment     = 1
   policy_type            = "SimpleScaling"
   adjustment_type        = "ChangeInCapacity"
   cooldown               = 300
   autoscaling_group_name = aws_autoscaling_group.patra-AG.name
  }
resource "aws_lb_target_group" "patra" {
    name     = "my-lb"
    port     =  80
    protocol = "HTTP"
    vpc_id   = aws_vpc.main.id
  }
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
  }
resource "aws_autoscaling_attachment" "asg_attachment_patra" {
  autoscaling_group_name = aws_autoscaling_group.patra-AG.id
  alb_target_group_arn   = aws_lb_target_group.patra.arn
}


variable "aws_access_key" {}
variable "aws_secret_key" {}

resource "aws_subnet" "public1" {

  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.101.0/24"
  }

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.102.0/24"
  }

resource "aws_subnet" "public3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.103.0/24"
  }

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "b1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.route.id
}
resource "aws_route_table_association" "b2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.route.id
}
resource "aws_route_table_association" "b3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.route.id

resource "aws_key_pair" "deployer" {
  key_name   = "PatraBastion"
  public_key = "file("/home/ec2-user/.ssh/id_rsa.pub")"
}

resource "aws_security_group" "allow_inbound" {
  name        = "allow_inbound"
  description = "Allow TLS inbound traffic"

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_inbound"
  }
}
