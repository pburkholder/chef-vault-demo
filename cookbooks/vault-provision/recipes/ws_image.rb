#
# Cookbook Name:: i2d_aws
# Recipe:: ws
# Copyright (c) 2015 The Authors, All Rights Reserved.

# Workstation Recipe


require 'chef/provisioning/aws_driver'
require_relative '../libraries/helpers'


with_driver 'aws::us-east-1' do
  aws_security_group 'ws.fluxx'
    description      name
    inbound_rules   '0.0.0.0/0' => 22
#    #inbound_rules   '71.178.0.0/16' => 22
  end

  machine_image 'ws' do
    recipe 'i2d_workstation::default'

    add_machine_options bootstrap_options: {
      instance_type: 'm1.small',
      image_id: 'ami-d85e75b0',
      iam_instance_profile: 'cheffian-ec2-bootstrap',
      key_name: 'divdevops_workshop',
    }
  end

end
