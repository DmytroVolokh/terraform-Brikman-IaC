provider "aws" {
  region = "eu-central-1"
}

resource "aws_instance" "example" {
  ami                    = "ami-05f7491af5eef733a"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data              = file(user_data.sh)
              EOF
  tags = {
    Name = "Brikman-example"
  }
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
