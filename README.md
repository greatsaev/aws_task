# AWS Task
This code deploys 2 WordPress CMS EC2 instances in AWS Cloud accesible by Load Balancer:

![Task](task.png)


# Usage

## Install

`terraform init`

`terraform apply`

Input your AWS IAM user credentials, confirm deployment and wait till **Balancer-Wordpress** URL will be shown in output section. Follow that link to access WordPress CMS. Hostname of WordPress instance will be shown after title

## Unistall

`terraform destroy`

