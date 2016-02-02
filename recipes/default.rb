#
# Cookbook Name:: chef-vault-demo-cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

package 's3cmd'

directory '/home/ubuntu'

aws = data_bag_item('cleartext', 'aws')
aws_secret_key = aws['aws_secret_key']
aws_access_key = aws['aws_access_key']

template '/home/ubuntu/.s3cfg' do
  source 's3cfg.erb'
  owner 'root'
  group 'root'
  mode 00744
  variables ({
    aws_secret_key: aws_secret_key,
    aws_access_key: aws_access_key
  }
  )
end

execute 'run_s3cmd' do
  command 's3cmd get -c /home/ubuntu/.s3cfg s3://chef-vault-demo/minikitten.png'
  creates '/home/ubuntu/minikitten.png'
  cwd '/home/ubuntu'
  action :run
end
