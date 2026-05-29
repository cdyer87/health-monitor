# --- WEST COAST DEPLOYMENT (US-WEST-2) ---

# 1. The Backup VPC
resource "aws_vpc" "west_network" {
  provider             = aws.west
  cidr_block           = "10.1.0.0/16" # Different CIDR to prevent IP overlap
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "enterprise-web-vpc-west"
    Environment = "production-ready"
    Project     = "AutoScalingWebStack"
  }
}

# 2. West Coast Internet Gateway
resource "aws_internet_gateway" "west_igw" {
  provider = aws.west
  vpc_id   = aws_vpc.west_network.id

  tags = { Name = "enterprise-igw-west" }
}

# 3. West Coast Public Subnets (We need 2 for a Load Balancer)
resource "aws_subnet" "west_public_subnet_1" {
  provider                = aws.west
  vpc_id                  = aws_vpc.west_network.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = { Name = "public-subnet-west-2a" }
}

resource "aws_subnet" "west_public_subnet_2" {
  provider                = aws.west
  vpc_id                  = aws_vpc.west_network.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2b"

  tags = { Name = "public-subnet-west-2b" }
}

# 4. West Coast Route Table & Associations
resource "aws_route_table" "west_public_rt" {
  provider = aws.west
  vpc_id   = aws_vpc.west_network.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.west_igw.id
  }

  tags = { Name = "public-route-table-west" }
}

resource "aws_route_table_association" "west_public_assoc_1" {
  provider       = aws.west
  subnet_id      = aws_subnet.west_public_subnet_1.id
  route_table_id = aws_route_table.west_public_rt.id
}

resource "aws_route_table_association" "west_public_assoc_2" {
  provider       = aws.west
  subnet_id      = aws_subnet.west_public_subnet_2.id
  route_table_id = aws_route_table.west_public_rt.id
}
# --- WEST COAST COMPUTE & LOAD BALANCING ---

# 5. West Coast Security Groups
resource "aws_security_group" "west_alb_sg" {
  provider    = aws.west
  name        = "enterprise-alb-sg-west-${terraform.workspace}"
  description = "Allow HTTP and HTTPS from the internet"
  vpc_id      = aws_vpc.west_network.id

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
}

resource "aws_security_group" "west_web_sg" {
  provider    = aws.west
  name        = "enterprise-web-sg-west-${terraform.workspace}"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.west_network.id

  ingress {
    description = "Allow HTTP inbound from corporate VPN/trusted IP only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["76.139.93.89/32"] # Matching your East Coast IP restriction
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. West Coast AMI and Launch Template
data "aws_ami" "west_amazon_linux" {
  provider    = aws.west
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "west_web_template" {
  provider      = aws.west
  name_prefix   = "enterprise-web-west-"
  image_id      = data.aws_ami.west_amazon_linux.id
  instance_type = "t2.micro" 
  key_name = "Amazonkey"

  vpc_security_group_ids = [aws_security_group.west_web_sg.id]

  # The Custom West Coast Boot Script
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Failover Successful! You are now viewing the West Coast Backup.</h1>" > /var/www/html/index.html
  EOF
  )
}

# 7. West Coast Load Balancer & Target Group
resource "aws_lb" "west_web_alb" {
  provider           = aws.west
  name               = "enterprise-alb-west-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.west_alb_sg.id]
  subnets            = [aws_subnet.west_public_subnet_1.id, aws_subnet.west_public_subnet_2.id]
}

resource "aws_lb_target_group" "west_web_tg" {
  provider = aws.west
  name     = "enterprise-tg-west-${terraform.workspace}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.west_network.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

# 8. West Coast Auto Scaling Group
resource "aws_autoscaling_group" "west_web_asg" {
  provider            = aws.west
  name                = "enterprise-asg-west-${terraform.workspace}"
  vpc_zone_identifier = [aws_subnet.west_public_subnet_1.id, aws_subnet.west_public_subnet_2.id]
  target_group_arns   = [aws_lb_target_group.west_web_tg.arn]

  desired_capacity = 2
  max_size         = 3
  min_size         = 1

  launch_template {
    id      = aws_launch_template.west_web_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "enterprise-server-west"
    propagate_at_launch = true
  }
}
# --- WEST COAST SSL & LISTENERS ---

# 9. Request the West Coast SSL Certificate
resource "aws_acm_certificate" "west_cert" {
  provider                  = aws.west
  domain_name               = "goodtimes.click"
  subject_alternative_names = ["*.goodtimes.click"]
  validation_method         = "DNS"
  tags = { Name = "enterprise-ssl-cert-west" }
}

# 10. Automate the West Coast SSL DNS Validation
resource "aws_route53_record" "west_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.west_cert.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "west_cert_val" {
  provider                = aws.west
  certificate_arn         = aws_acm_certificate.west_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.west_cert_validation : record.fqdn]
}

# 11. West Coast ALB Listeners
resource "aws_lb_listener" "west_http" {
  provider          = aws.west
  load_balancer_arn = aws_lb.west_web_alb.arn
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

resource "aws_lb_listener" "west_https" {
  provider          = aws.west
  load_balancer_arn = aws_lb.west_web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.west_cert_val.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.west_web_tg.arn
  }
}


# --- GLOBAL DNS FAILOVER (THE TRAFFIC COP) ---

# 12. Primary Record (East Coast)
resource "aws_route53_record" "primary" {
  zone_id        = data.aws_route53_zone.main.zone_id
  name           = "goodtimes.click"
  type           = "A"
  set_identifier = "EastCoastPrimary" # Required for failover records

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true # Route53 watches the East Coast servers!
  }
}

# 13. Secondary Backup Record (West Coast)
resource "aws_route53_record" "secondary" {
  zone_id        = data.aws_route53_zone.main.zone_id
  name           = "goodtimes.click"
  type           = "A"
  set_identifier = "WestCoastBackup"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_lb.west_web_alb.dns_name
    zone_id                = aws_lb.west_web_alb.zone_id
    evaluate_target_health = true 
  }
}