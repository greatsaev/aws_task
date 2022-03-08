provider "aws" {
  region     = "eu-central-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# resource "aws_key_pair" "ssh_key" { 
#   key_name   = "aws-public-key" 
#   public_key = var.aws_ssh_pub_key
# }

# ---
# --- VPC ---
# ---

resource "aws_vpc" "wp_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# --- IGW ---

resource "aws_internet_gateway" "wpc_igw" {
  vpc_id     = aws_vpc.wp_vpc.id
  depends_on = [aws_vpc.wp_vpc]
}

resource "aws_route" "wpc_igw_route" {
  route_table_id         = aws_vpc.wp_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.wpc_igw.id
  depends_on             = [aws_internet_gateway.wpc_igw, aws_vpc.wp_vpc]
}

# --- Subnets ---

resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.wp_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.wp_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
}

resource "aws_route_table_association" "subnet_1_route" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_vpc.wp_vpc.main_route_table_id
}

resource "aws_route_table_association" "subnet_2_route" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_vpc.wp_vpc.main_route_table_id
}

# ---
# --- Security Groups ---
# ---

resource "aws_security_group" "sg_ec2" {
  name        = "ec2_sg"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description = "Allow inbound HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow inbound SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.189.65.120/29"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_rds" {
  name        = "rds_sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description     = "Allow inbound MySQL traffic"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  egress {
    description = "Allow outbound traffic to VPC subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  depends_on = [aws_security_group.sg_ec2]
}

resource "aws_security_group" "sg_efs" {
  name        = "efs_sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description     = "Allow inbound NFS traffic"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  egress {
    description = "Allow outbound traffic to VPC subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  depends_on = [aws_security_group.sg_ec2]
}

resource "aws_security_group" "sg_lb" {
  name        = "lb_sg"
  description = "Security group for LB"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description = "Allow inbound HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Allow outbound HTTP traffic to EC2 instances"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  depends_on = [aws_security_group.sg_ec2]
}

# ---
# --- EFS ---
# ---

resource "aws_efs_file_system" "wp_efs" {
  encrypted = true
}

resource "aws_efs_mount_target" "subnet_1_efs" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.subnet_1.id
  security_groups = [aws_security_group.sg_efs.id]
  depends_on      = [aws_efs_file_system.wp_efs, aws_security_group.sg_efs]
}

resource "aws_efs_mount_target" "subnet_2_efs" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.subnet_2.id
  security_groups = [aws_security_group.sg_efs.id]
  depends_on      = [aws_efs_file_system.wp_efs, aws_security_group.sg_efs]
}

# ---
# --- RDS ---
# ---

resource "aws_db_subnet_group" "wp_db_sg" {
  name       = "db_sg_for_wp"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
}

resource "aws_db_instance" "wp_db" {
  identifier             = "wp-db"
  engine                 = "mysql"
  instance_class         = "db.t2.micro"
  db_subnet_group_name   = aws_db_subnet_group.wp_db_sg.name
  db_name                = var.wp_db_name
  username               = var.wp_db_user
  password               = var.wp_db_pass
  allocated_storage      = 5
  max_allocated_storage  = 0
  storage_type           = "gp2"
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  skip_final_snapshot    = true
  depends_on             = [aws_security_group.sg_rds, aws_db_subnet_group.wp_db_sg]
}

# ---
# --- Load Balancer ---
# ---

resource "aws_lb" "wp_lb" {
  name                       = "wp-lb"
  drop_invalid_header_fields = true
  security_groups            = [aws_security_group.sg_lb.id]
  subnets                    = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  depends_on                 = [aws_security_group.sg_lb]
}

resource "aws_lb_target_group" "lb_tg" {
  name     = "lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wp_vpc.id

  health_check {
    path     = "/wp-login.php"
    port     = "80"
    protocol = "HTTP"
    matcher  = "200"
  }
}

resource "aws_lb_listener" "lb_http_listener" {
  load_balancer_arn = aws_lb.wp_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lb_tg.arn
    type             = "forward"
  }
}

# ---
# --- EC2 Instances ---
# ---

data "template_file" "cl_init1" {
  template           = file ("./install_wp.tpl")
  vars = {
    "efs_mount_dns" = aws_efs_file_system.wp_efs.dns_name
    "db_endpoint"   = aws_db_instance.wp_db.endpoint
    "db_name"       = var.wp_db_name
    "db_user"       = var.wp_db_user
    "db_pass"       = var.wp_db_pass
    "site_url"      = aws_lb.wp_lb.dns_name
    "admin_name"    = var.wp_admin_name
    "admin_pass"    = var.wp_admin_pass
    "admin_email"   = var.wp_admin_email
  }
  depends_on = [aws_db_instance.wp_db, aws_efs_file_system.wp_efs, aws_lb.wp_lb]
}

data "template_file" "cl_init2" {
  template           = file ("./cl_init2.tpl")
  vars = {
    "efs_mount_dns" = aws_efs_file_system.wp_efs.dns_name
  }
  depends_on = [aws_efs_file_system.wp_efs]
}


resource "aws_instance" "web1" {
  ami = "ami-0d527b8c289b4af7f"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sg_ec2.id]
  subnet_id       = aws_subnet.subnet_1.id
  associate_public_ip_address = true
  user_data       = data.template_file.cl_init1.rendered
#  key_name        = aws_key_pair.ssh_key.key_name
  depends_on      = [aws_db_instance.wp_db, aws_lb.wp_lb]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "web2" {
  ami = "ami-0d527b8c289b4af7f"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.sg_ec2.id]
  subnet_id       = aws_subnet.subnet_2.id
  associate_public_ip_address = true
  user_data       = data.template_file.cl_init2.rendered
  depends_on      = [aws_db_instance.wp_db, aws_lb.wp_lb, aws_instance.web1]
#  key_name        = aws_key_pair.ssh_key.key_name
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_target_group_attachment" "tg_attach_wp1" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
  depends_on       = [aws_instance.web1]
}


resource "aws_lb_target_group_attachment" "tg_attach_wp2" {
  target_group_arn = aws_lb_target_group.lb_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
  depends_on       = [aws_instance.web2]
}

# ---
# ---
# ---

output "Balancer-Wordpress" {
  value = "http://${aws_lb.wp_lb.dns_name}"
}