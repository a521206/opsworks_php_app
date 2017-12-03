# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY OpsCode
# This template deploys OpsCode stack
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
  region = "ap-south-1"
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
  custom_cookbooks_source{
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

  # chef
  custom_setup_recipes     = []
  custom_configure_recipes = []
  custom_deploy_recipes    = ["phpapp::dbsetup"]
  custom_undeploy_recipes  = []
  custom_shutdown_recipes  = []
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
    instance_type               = "t2.micro"
    state                       = "running"
    root_device_type            = "ebs"
}

resource "aws_db_instance" "instance_mysql" {
  allocated_storage    = 10
  storage_type         = "standard"
  engine               = "mysql"
  engine_version       = "5.7.19"
  instance_class       = "db.t2.small"
  name                 = "simplephpapp"
  username             = "root"
  password             = "SimplePassword01"
}

resource "aws_opsworks_rds_db_instance" "opsworks_db_instance" {
  stack_id            = "${aws_opsworks_stack.stack_myphp.id}"
  rds_db_instance_arn = "${aws_db_instance.instance_mysql.arn}"
  db_user             = "${aws_db_instance.instance_mysql.username}"
  db_password         = "${aws_db_instance.instance_mysql.password}"
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
  description = "This is a PHP demo appl ication"

  app_source = {
    type     = "git"
    revision = "version2"
    url      = "https://github.com/amazonwebservices/opsworks-demo-php-simple-app"
  }

  document_root             = "web"
  data_source_type          = "OpsworksMysqlInstance"
  data_source_arn           = "${aws_db_instance.instance_mysql.arn}"
  data_source_database_name = "simplephpapp"
}