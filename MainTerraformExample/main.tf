# IaC Buildout for Terraform Associate Exam
/*
Ryan Rosiak
08/13/23
*/

# Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# Query S3 bucket using data block (existing data)
data "aws_s3_bucket" "data_bucket" {
  bucket = "my-data-lookup-bucket-ry-rosi"
}

# Resource created and querying data from our bucket data block
resource "aws_iam_policy" "policy" {
  name        = "data_bucket_policy"
  description = "Allow access to my bucket"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ],
        "Resource" : "${data.aws_s3_bucket.data_bucket.arn}"
      }
    ]
  })
  // Get exported arn key of bucket in above line
}

# Local Variables Example
# Can be used to define values that will be repeated over and over again
# **Can define string literals, expressions, and use other interpolated locals
locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
  server_name = "ec2-${var.environment}-api-${var.variables_sub_az}"
}

# You can put all locals in one block or separate them into multiple blocks for various purposes
locals {
  service_name = "Automation"
  app_team     = "Cloud Team"
  createdby    = "terraform"
}

// Can assign our "local" locals and then assign them to "standard" sets of local variables
locals {
  // Group into common tags so you dont have to interpolate each individual variable within your code, add them all at once with one reference
  common_tags = {
    Name      = lower(local.server_name)
    Owner     = lower(local.team)
    App       = lower(local.application)
    Service   = lower(local.service_name)
    AppTeam   = lower(local.app_team)
    CreatedBy = lower(local.createdby)
  }
}

// Using some in-built Terraform functions
locals {
  maximum = max(var.num_1, var.num_2, var.num_3)
  minimum = min(var.num_1, var.num_2, var.num_3)
}


# Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = upper(var.vpc_name)
    Environment = upper(var.environment)
    Terraform   = upper("true")
    Region      = data.aws_region.current.name
  }
}

# Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value) // Chop our base CIDR into multiple subnets
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100) // 10.0.<each.value>.0/<bits>
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

# Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}
resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

# Create internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

# Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "demo_igw_eip"
  }
}

# Create the NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "demo_nat_gateway"
  }
}

# Terraform Data Block - To lookup latest Ubuntu 20.04 AMI image
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# Terraform Resource Block - To build EC2 instance in public subnet
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups             = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id, aws_security_group.vpc-ping.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  # This connection block will be used for the "remote-exec" provisioner
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }
  # Actual Provisioner (Must have a connection block set up in the EC2 instance like the one above)
  # Will below provisioner will not work for windows
  # provisioner "local-exec" {
  #   command = "chmod 600 ${local_file.private_key_pem.filename}"
  # }
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp",
      "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
      "sudo sh /tmp/assets/setup-web.sh",
    ]

  }
  // Instead of manual instantiation, set a whole dictionary of common tags
  tags = local.common_tags
  # {
  #   Name           = "Ubuntu EC2 Server"
  #   Owner          = local.team
  #   App            = local.application
  #   "service_name" = "Automation" // Can use quotes for key (if a space is needed) otherwise, can keep normal
  #   app_team       = "Cloud Team"
  #   createdby      = "terraform"
  # }
  lifecycle {
    ignore_changes = [security_groups]
  }
}

# resource "aws_instance" "web" {
#   ami                    = "ami-09538990a0c4fe9be"
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.public_subnets["public_subnet_1"].id
#   vpc_security_group_ids = ["sg-00ed13934e19ad957"]
#   tags = {
#     "Terraform" = "true"
#   }
# }


# resource "aws_s3_bucket" "my-new-S3-bucket" {
#   bucket = "my-new-tf-bucket-ryan-rosi-${random_id.randomness.hex}"

#   tags = {
#     Name    = "My S3 Bucket"
#     Purpose = "Intro to Resource Blocks Lab"
#   }
# }

# resource "aws_s3_bucket_acl" "my_new_bucket_acl" {
#   bucket = aws_s3_bucket.my-new-S3-bucket.id
#   acl    = "private"
# }

resource "aws_security_group" "my-new-security-group" {
  name        = "web_server_inbound"
  description = "Allow inbound traffic on tcp/443"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow 443 from the Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "web_server_inbound"
    Purpose = "Intro to Resource Blocks Lab"
  }
}

# Will break, need to either run terraform init or change the resource
# Since the aws provider alone does not have this resource (Terraform will try to find one that will have it)
resource "random_id" "randomness" {
  byte_length = 16
}

# We dont want these static values, lets look to the variables.tf file
resource "aws_subnet" "variables-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = var.variables_sub_az
  map_public_ip_on_launch = var.variables_sub_auto_ip
  tags = {
    Name      = "sub-variables-${var.variables_sub_az}"
    Terraform = "true"
  }
}

# For generating TLS private key (Using TLS provider)
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

# Save the key to a PEM file (using local provider)
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
}

# Generate AWS Key Pair
resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey-${var.environment}"
  public_key = tls_private_key.generated.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]
  }
}

# Allow remote-exec provisioner to talk to our EC2 instance
resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow specific web traffic to the EC2 instance
resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

  }
  egress {
    description = "Allow all IP and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "vpc-ping" {
  name        = "vpc-ping"
  vpc_id      = aws_vpc.vpc.id
  description = "ICMP for Ping Access"
  ingress {
    description = "Allow ICMP Traffic"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outboun"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Create a module from a local source 
// All code within the 
module "server" {
  source          = "./modules/server"
  ami             = data.aws_ami.ubuntu.id
  size            = "t2.micro"
  subnet_id       = aws_subnet.public_subnets["public_subnet_3"].id
  security_groups = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id, aws_security_group.vpc-ping.id]
}

// Display outputs for server defined above
output "public_dns" {
  value = module.server.public_dns
}

output "size" {
  value = module.server.size
}

// Each argument in the module is a variable in the module source that is expecting a value
module "server_subnet_1" {
  source          = "./modules/web_server"
  ami             = data.aws_ami.ubuntu.id
  key_name        = aws_key_pair.generated.key_name
  user            = "ubuntu"
  private_key     = tls_private_key.generated.private_key_pem
  subnet_id       = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id, aws_security_group.vpc-ping.id, aws_security_group.main.id]
}

// Ouput of module above
output "public_ip_server_subnet_1" {
  value = module.server_subnet_1.public_ip
}

// Sourced from the Terraform Module registry
module "autoscaling_pmr" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"
  # Autoscaling group
  name                = "myasg"
  vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id, aws_subnet.private_subnets["private_subnet_2"].id, aws_subnet.private_subnets["private_subnet_3"].id]
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1
  # Launch template
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    "Name" = "Web EC2 Server 2"
  }
}

// Sourced from GitHub
module "autoscaling_gh" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling?ref=v6.10.0"
  # Autoscaling group
  name                = "myasg"
  vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id, aws_subnet.private_subnets["private_subnet_2"].id, aws_subnet.private_subnets["private_subnet_3"].id]
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1
  # Launch template
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags = {
    "Name" = "Web EC2 Server 2"
  }
}

// Pulled from a child module, only can be pulled because the module explicitly exposed it 
output "asg_group_size" {
  value = module.autoscaling_gh.autoscaling_group_max_size

}

// Sourcing another module from TMR
module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.14.1"
}

output "s3_bucket_name" {
  value = module.s3-bucket.s3_bucket_bucket_domain_name
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = ">3.0.0"
  name               = "my-vpc-terraform"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true
  tags = {
    Name        = "VPC from Module"
    Terraform   = "true"
    Environment = "dev"
  }
}

// Created from list and map in variables.tf
resource "aws_subnet" "list_subnet" {
  // Loop through every key in the map
  for_each = var.env
  vpc_id   = aws_vpc.vpc.id
  // From mapped value
  // Need to use each.value as our "index" of each iteration
  cidr_block = each.value.ip // Grab value from another variable
  // Must index here
  //availability_zone = var.us-east-1-azs[0]
  availability_zone = each.value.az
}

// Using dynamic blocks
// Do it with variable instead of locals
// Only use the dynamic blocks for large amounts of nested configurations or when you need to hide
// high level abstract code
# locals {
#   ingress_rules = [{
#     port        = 443
#     description = "Port 443"
#     },
#     {
#       port        = 80
#       description = "Port 80"
#     }
#   ]
# }

resource "aws_security_group" "main" {
  // Due to a dependency, the security group will need to be destroyed before it can be recreated because
  // the server is using the security group and it will break the dependency graph
  // What we need to do is use a lifecycle directive
  // See lifecycle block and directive outlined below
  name   = "core-sg-global"
  vpc_id = aws_vpc.vpc.id
  // Without dynamic blocks
  # ingress {
  #   description = "Port 443"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  # ingress {
  #   description = "Port 80"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  // Dynamic blocks
  // Loop through the ingress rules defined above and write only ONE configuration for ingress rules
  dynamic "ingress" {
    //for_each = local.ingress_rules
    for_each = var.web_ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      # protocol    = "tcp"
      # cidr_blocks = ["0.0.0.0/0"]
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  // Use this lifecycle rule to break the aforementioned dependency
  lifecycle {
    create_before_destroy = true
    //prevent_destroy       = true
  }
}