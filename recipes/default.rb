#
# Cookbook Name:: chef-vault-demo-cookbook
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

directory ('/home/ubuntu')

file ('/home/ubuntu/foo') do
  content "Hello\n"
end

file ('/home/ubuntu/foo.bar') do
  content "There\n"
end
