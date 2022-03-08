variable "aws_access_key" {
  description = "Enter your AWS access_key"
}
variable "aws_secret_key" {
  description = "Enter your AWS secret_key"
}
variable "wp_db_name" {
    default = "wpdb"
}
variable "wp_db_user" {
    default = "wpadm"
}
variable "wp_db_pass" {
    default = "zxcVFR321"
}
variable "wp_admin_name" {
    default = "wpadm"
}
variable "wp_admin_pass" {
    default = "zxcVFR321"
}
variable "wp_admin_email" {
    default = "admin@example.com"
    description = "Enter your email"
}

# variable "aws_ssh_pub_key" {
#     #default = ""
#     description = "Enter your SSH public key"
# }