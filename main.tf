provider "aws" {
  region = "eu-central-1"
}

resource "aws_launch_configuration" "example" {
  image_id        = "ami-05f7491af5eef733a"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]
  user_data       = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  target_group_arns    = [aws_lb_target_group.asg.arn]
  health_check_type    = "ELB"
  min_size             = 2
  max_size             = 10
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids
  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = "terraform-example-alb"
  ingress {
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
}

resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    field  = "path-pattern"
    values = ["*"]
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
