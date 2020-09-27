provider "aws" {
	region = "ap-south-1"
	profile = "arpit"
}

//Generating Key pair

resource "tls_private_key" "key-pair" {
algorithm = "RSA"
}

resource "aws_key_pair" "key" {
key_name = "arpitT1"
public_key = tls_private_key.key-pair.public_key_openssh

depends_on = [ tls_private_key.key-pair ,]
}


//Generating Security Group

resource "aws_security_group" "task-security" {
    depends_on = [aws_key_pair.key,]
	name = "task-security"
	description = "SSH and HTTP"

	ingress {
		description = "SSH"
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = [ "0.0.0.0/0" ]
	}

	ingress {
		description = "HTTP"
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = [ "0.0.0.0/0" ]
	}

	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "task-security"
	}
}


// Launching The Instance
resource "aws_instance" "task1" {
	depends_on = [aws_security_group.task-security,]
	ami           = "ami-0447a12f28fddb066"
	instance_type = "t2.micro"
	key_name = aws_key_pair.key.key_name
	security_groups = [ "task-security" ]

// Connecting to the instance
	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = tls_private_key.key-pair.private_key_pem
		host     = aws_instance.task1.public_ip
	}

// Installing the requirements
	provisioner "remote-exec" {
		inline = [
			"sudo yum install httpd  php git -y",
			"sudo systemctl restart httpd",
			"sudo systemctl enable httpd",
		]
	}

	tags = {
		Name = "task-1"
	}

}


// Launching a persistant EBS volume 
resource "aws_ebs_volume" "task-vol" {
	availability_zone = aws_instance.task1.availability_zone
	size              = 1
	tags = {
		Name = "task-1vol"
	}
}


// Attaching the volume to instance
resource "aws_volume_attachment" "attach-vol" {
	device_name = "/dev/sdh"
	volume_id   = aws_ebs_volume.task-vol.id
	instance_id = aws_instance.task1.id
	force_detach = true
}


output "task-instance-ip" {
	value = aws_instance.task1.public_ip
}


//Connect to instance again
resource "null_resource" "remote-connect"  {

depends_on = [aws_volume_attachment.attach-vol,]

	connection {
		type     = "ssh"
		user     = "ec2-user"
		private_key = tls_private_key.key-pair.private_key_pem
		host     = aws_instance.task1.public_ip
	}
	
//Format the EBS--> Mount it-->Download Code from GitHub
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Arpit114/AWS_Terraform_Github.git /var/www/html/"
    ]
  }
}


//Connect to the webserver to see the website
resource "null_resource" "webpage"  {

depends_on = [null_resource.remote-connect,]

	provisioner "local-exec" {
	    command = "start chrome ${aws_instance.task1.public_ip}"
  	}
}


