#
# Cookbook Name:: chef-vault-demo-cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

directory('/etc/chef').run_action(:create)

cookbook_file '/etc/chef/encrypted_data_bag_secret' do
  source 'encrypted_data_bag_secret'
  owner 'root'
  group 'root'
  mode 00006
end.run_action(:create)

aws = data_bag_item(
  'encrypted', 'aws', IO.read('/etc/chef/encrypted_data_bag_secret')
)
aws_secret_key = aws['aws_secret_key']
aws_access_key = aws['aws_access_key']

package 's3cmd'

directory '/home/ubuntu'

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
