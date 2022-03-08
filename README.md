# AWS Task
This code deploys 2 WordPress CMS EC2 instances in AWS Cloud accesible by Load Balancer:

![Task](task.png)


# Usage

## Install

`terraform init`

`terraform apply`

Input your AWS IAM user credentials, confirm deployment and wait till **Balancer-Wordpress** URL will be shown in output section. Follow that link to access WordPress CMS(It may take some time(3-5 min) to finally complete installation). Hostname of WordPress instance will be shown on page after title

## Unistall

`terraform destroy`

