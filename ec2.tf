resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_subnet.id
  private_ip                  = "10.0.1.10"
  security_groups = [
    aws_security_group.web_sg.id
  ]
  key_name = aws_key_pair.auth.id

  provisioner "remote-exec" {
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
    }
    inline = [
      "sudo yum -y install httpd",
      "sudo systemctl start httpd.service",
      "sudo systemctl enable httpd.service"
    ]
  }

  tags = {
    Name = "Web サーバー"
  }
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.private_subnet.id
  private_ip                  = "10.0.2.10"
  security_groups = [
    aws_security_group.db_sg.id
  ]
  key_name = aws_key_pair.auth.id

  tags = {
    Name = "DB サーバー"
  }
}
