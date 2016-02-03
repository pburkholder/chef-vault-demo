#
# Cookbook Name:: chef-vault-demo-cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# Note -- this only works if you've distributed the secret
# out-of-band from Chef itself. For PeterB's use with dokken,
# I used an `intermediate_instructions` in the .kitchen, test-kitchen
# and manually copied the key to the OsX tmpdir which I unearthed in
# with find ... dokken in /var/folders...

aws = data_bag_item(
  'encrypted', 'aws', IO.read('/root/encrypted_data_bag_secret')
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
