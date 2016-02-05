#
# Cookbook Name:: i2d_aws
# Recipe:: ws
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Workstation Recipe


require 'chef/provisioning/aws_driver'
require_relative '../libraries/helpers'
group_name = 'vault-provision'

with_driver 'aws::us-east-1' do
  aws_security_group group_name  do
    description     name
    inbound_rules   '0.0.0.0/0' => 22
  end

  aws_launch_configuration group_name do
    image 'ami-ad3718c7'  # Trusty
    instance_type 't2.micro'
    options({
      security_groups: [ group_name ],
      iam_instance_profile: 'pburkholder-ec2-bootstrap',
      key_pair: 'pburkholder-one',
      user_data: user_data  # from libraries/helper.rb method
    })
  end

  aws_auto_scaling_group group_name do
    desired_capacity 3
    min_size 0
    max_size 6
    launch_configuration group_name
    availability_zones ['us-east-1c']
  end
end
