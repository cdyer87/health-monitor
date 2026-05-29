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
} # 

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
  key_name               = "Amazonkey"

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
  
  # Change 1: Added the second subnet
  vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  
  # Change 2: Wired to the Load Balancer
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

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
# --- Upgrade 1: The Private Vault (Database Tier) ---

# 1. Private Subnets (AWS requires 2 for an RDS DB Subnet Group)
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_network.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "enterprise-private-subnet-1" }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_network.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "enterprise-private-subnet-2" }
}

# 2. NAT Gateway & Elastic IP (The secure one-way window)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id # NAT MUST live in the public subnet
  tags = { Name = "enterprise-nat-gateway" }
}

# 3. Private Route Table & Associations
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_network.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "enterprise-private-rt" }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# 4. Database Security Group (The Vault Door)
resource "aws_security_group" "db_sg" {
  name        = "enterprise-db-sg"
  description = "Allow MySQL traffic strictly from Web Tier"
  vpc_id      = aws_vpc.main_network.id

  ingress {
    description     = "MySQL from Web Servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    # This is the magic! It references your Phase 2 web bouncer:
    security_groups = [aws_security_group.web_sg.id] 
  }

  tags = { Name = "enterprise-db-security-group" }
}

# 5. DB Subnet Group & RDS MySQL Database
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "enterprise-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = { Name = "enterprise-db-subnet-group" }
}

resource "aws_db_instance" "app_database" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Free-tier eligible
  identifier             = "enterprise-db"
  username               = "admin"
  password               = "SuperSecretPassword123!" # Hardcoded for learning; in prod we'd use AWS Secrets Manager
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true # Makes tearing down the project much faster
  
  tags = { Name = "enterprise-mysql-db" }
}
# FREELANCE UPGRADE NOTE: 
  # When deploying for a paying client, uncomment the line below to enable 99.95% High Availability
  # multi_az = true
  # --- Upgrade 2: The Professional Front (Load Balancer & SSL) ---

# 1. The Second Public Subnet (ALBs require at least 2 AZs!)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_network.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1b" }
}

# Link the new subnet to the internet
resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. ALB Security Group (The Front Door Bouncer)
resource "aws_security_group" "alb_sg" {
  name        = "enterprise-alb-sg"
  description = "Allow HTTP and HTTPS from the internet"
  vpc_id      = aws_vpc.main_network.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "enterprise-alb-sg" }
}

# 3. Application Load Balancer
resource "aws_lb" "web_alb" {
  name               = "enterprise-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  tags = { Name = "enterprise-web-alb" }
}

# 4. Target Group (The "bucket" of servers the ALB sends traffic to)
resource "aws_lb_target_group" "web_tg" {
  name     = "enterprise-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_network.id

  # The ALB will constantly ping this to make sure your servers are alive
  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

# 5. Request the SSL Certificate for your new domain
resource "aws_acm_certificate" "cert" {
  domain_name               = "goodtimes.click"
  subject_alternative_names = ["*.goodtimes.click"]
  validation_method         = "DNS"
  tags = { Name = "enterprise-ssl-cert" }
}
# --- Upgrade 3: The Final Wire-Up (DNS & Listeners) ---

# 1. Grab the Hosted Zone AWS created for your domain
data "aws_route53_zone" "main" {
  name         = "goodtimes.click"
  private_zone = false
}

# 2. Automate the SSL DNS Validation (Proving you own the domain)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cert_val" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 3. The Listeners (Telling the Load Balancer what to do)
# If someone types http:// (Port 80), redirect them to secure https://
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# If someone types https:// (Port 443), send them to the web servers!
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_val.certificate_arn # Waits for validation!

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}