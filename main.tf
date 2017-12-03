# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY OpsCode
# This template deploys OpsCode stack
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
  region = "ap-south-1"
}

data "aws_caller_identity" "iamuser" {}


data "aws_region" "region" {
  current = true
}

# ------------------------------------------------------------------------------
# CONFIGURE OUR AWS STACK
# ------------------------------------------------------------------------------

resource "aws_opsworks_stack" "stack_myphp" {
  name                          = "myphp-stack"
  region                        = "ap-south-1"
  default_os                    = "Amazon Linux 2017.09"
  default_ssh_key_name          = "TerraformDemo"
  configuration_manager_name    = "Chef"
  configuration_manager_version = "11.10"

  use_custom_cookbooks          = true
  custom_cookbooks_source {
    type                        = "git"
    url                         = "https://github.com/amazonwebservices/opsworks-example-cookbooks.git"
  }
  manage_berkshelf              = false

  service_role_arn              = "arn:aws:iam::771987116335:role/aws-opsworks-service-role"
  default_instance_profile_arn  = "arn:aws:iam::771987116335:instance-profile/aws-opsworks-ec2-role"
  default_availability_zone     = "ap-south-1a"

  use_opsworks_security_groups  = true

  tags {
    Name                        = "myphp-demo"
  }

}

resource "aws_opsworks_mysql_layer" "layer_mysql" {
  name                          = "mysql-custom-layer"
  stack_id                      = "${aws_opsworks_stack.stack_myphp.id}"
 
  # network
  auto_assign_elastic_ips = false
  auto_assign_public_ips  = true
  drain_elb_on_shutdown   = true
  root_password           = "SimplePassword01"
  root_password_on_all_instances  = true

  # chef
  custom_setup_recipes     = []
  custom_configure_recipes = []
  custom_deploy_recipes    = ["phpapp::dbsetup"]
  custom_undeploy_recipes  = []
  custom_shutdown_recipes  = []

  ebs_volume {
    mount_point     = "/vol/mysql" 
    size            = 10
    type            = "standard" 
    number_of_disks = 1
  }

  auto_healing            = false
}

resource "aws_opsworks_php_app_layer" "layer_myphp" {
  name                          = "myphp-custom-layer"
  stack_id                      = "${aws_opsworks_stack.stack_myphp.id}"
 
  # network
  auto_assign_elastic_ips = false
  auto_assign_public_ips  = true
  drain_elb_on_shutdown   = true

  # chef
  custom_setup_recipes     = []
  custom_configure_recipes = []
  custom_deploy_recipes    = ["phpapp::appsetup"]
  custom_undeploy_recipes  = []
  custom_shutdown_recipes  = []
  }

# aws opsworks create-instance --stack-id "a5e392d5-4d3d-4907-9f97-223c49a6f15e" --layer-ids "03e69f92-35d0-4645-826f-82dba29c92b4" --instance-type t2.micro --hostname instance_myphp

resource "aws_opsworks_instance" "instance_myphp" {
    count                       = 1
    availability_zone           = "ap-south-1a"
    stack_id                    = "${aws_opsworks_stack.stack_myphp.id}"
    layer_ids                   = ["${aws_opsworks_php_app_layer.layer_myphp.id}"]
    os                          = "Amazon Linux 2017.09"
    instance_type               = "t2.small"
    state                       = "running"
    root_device_type            = "ebs"
}

resource "aws_opsworks_instance" "instance_mysql" {
    count                       = 1
    availability_zone           = "ap-south-1a"
    stack_id                    = "${aws_opsworks_stack.stack_myphp.id}"
    layer_ids                   = ["${aws_opsworks_mysql_layer.layer_mysql.id}"]
    os                          = "Amazon Linux 2017.09"
    instance_type               = "t2.small"
    state                       = "running"
    root_device_type            = "ebs" 
  }

resource "aws_opsworks_permission" "stack_permission" {
  allow_ssh  = true
  allow_sudo = true
  # level      = "manage"
  # "arn:aws:iam::771987116335:user/awsdemo"
  user_arn   = "arn:aws:iam::771987116335:user/awsdemo"
  stack_id   = "${aws_opsworks_stack.stack_myphp.id}"
}


resource "aws_opsworks_application" "app_myphp" {
  name        = "Simple PHP App"
  short_name  = "simplephpapp"
  stack_id    = "${aws_opsworks_stack.stack_myphp.id}"
  type        = "php"
  description = "This is a PHP demo application"

  app_source = {
    type     = "git"
    revision = "version2"
    url      = "https://github.com/amazonwebservices/opsworks-demo-php-simple-app"
  }

  document_root             = "web"
  data_source_type          = "OpsworksMysqlInstance"
  data_source_arn           = "arn:aws:opsworks:${data.aws_region.region.name}:${data.aws_caller_identity.iamuser.account_id}:instance/${aws_opsworks_instance.instance_mysql.id}"
  data_source_database_name = "simplephpapp"
}