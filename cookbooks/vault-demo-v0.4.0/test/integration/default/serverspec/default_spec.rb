require 'inspec'

# s3cmd package installed
describe package('s3cmd') do
  it { should be_installed }
end

# home/ubuntu/.s3cfg contains AKIA
describe file('/home/ubuntu/.s3cfg') do
  its('content') { should match /access_key = AKIA/ }
  its('content') { should match /secret: SubRosa/}
end

# command s3cmd fetches something
# is minikitten.png is in place?
describe file('/home/ubuntu/minikitten.png') do
  its('sha256sum') {
    should eq '50024ebd313ea4a5dab36171f222e6b8b07cbe1e2d0691d928e3e33d4da1b151'
  }
end
