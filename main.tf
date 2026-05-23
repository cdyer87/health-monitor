# main.tf - Foundation: The VPC

resource "aws_vpc" "main_network" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-web-vpc"
    Environment = "production-ready"
    Project     = "AutoScalingWebStack"
  }
} # <--- This is the closing bracket your new code needed to be below!

# 1. Internet Gateway (The front door)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_network.id

  tags = {
    Name = "enterprise-igw"
  }
}

# 2. Public Subnet (The web-facing room)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet-1a"
  }
}

# 3. Route Table (The traffic cop)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_network.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# 4. Route Table Association (Connecting the cop to the room)
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}
# 5. Security Group (The Bouncers)
resource "aws_security_group" "web_sg" {
  name        = "enterprise-web-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main_network.id

  # Inbound: Allow Web Traffic
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 0.0.0.0/0 means "from any IP address"
  }

  # Inbound: Allow Secure Admin Access
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # Outbound: Allow servers to talk to the internet
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # -1 means "all protocols"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "enterprise-security-group"
  }
}
# --- Phase 3: The Server Blueprint ---

# Find the latest Amazon Linux 2 Image dynamically
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 6. Launch Template (The Recipe)
resource "aws_launch_template" "web_template" {
  name_prefix   = "enterprise-web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro" # Free-tier eligible!

  # Attach the bouncer we made in Phase 2
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # The Boot Script: Install Apache Web Server and turn it on
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Success! Your Enterprise Architecture is running!</h1>" > /var/www/html/index.html
  EOF
  )

  tags = {
    Name = "enterprise-launch-template"
  }
}
# --- Phase 4: The Automation Engine ---

# 7. Auto Scaling Group (The Fleet Manager)
resource "aws_autoscaling_group" "web_asg" {
  name                = "enterprise-web-asg"
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id]
  
  # The Scaling Rules
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1

  # Pointing to your Phase 3 Blueprint
  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  # This automatically names every server the ASG builds
  tag {
    key                 = "Name"
    value               = "enterprise-asg-web-server"
    propagate_at_launch = true
  }
}