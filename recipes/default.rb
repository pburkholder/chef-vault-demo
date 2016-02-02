#
# Cookbook Name:: chef-vault-demo-cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

package 's3cmd'

directory '/home/ubuntu'

file '/home/ubuntu/.s3cfg' do
  content (
'
[default]
access_key = AKIAJWLDGDWB6HVRMRAQ
secret_key = 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
'
  )
end

execute 'run_s3cmd' do
  command 's3cmd get -c /home/ubuntu/.s3cfg s3://chef-vault-demo/minikitten.png'
  creates '/home/ubuntu/minikitten.png'
  cwd '/home/ubuntu'
  action :run
end
