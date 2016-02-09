require 'inspec'

describe file('/etc/passwd') do
  it { should exist }
  it { should be_file }
end

describe file('/home/ubuntu/foo') do
  it { should exist }
  it { should be_file }
end

describe file('/home/ubuntu/foo.bar') do
  it { should exist }
  it { should be_file }
end
