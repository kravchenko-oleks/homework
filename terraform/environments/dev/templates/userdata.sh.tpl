#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install docker -y 
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo docker pull ${docker_image}
sudo docker run --name nginx -p 80:80 -d ${docker_image}