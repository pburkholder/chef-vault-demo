# chef-vault-demo-cookbook

Welcome to the chef-vault-demo set of cookbooks.

The purpose of this project is present you with TK iterations of a cookbook that takes a secret, in one form or another, and uses it with a Chef `template` resource. The iterations are:

- vault-demo-1 : Use a clear-text data bag
- vault-demo-2 : Use an encrypted data bag
- vault-demo-3 : Use chef-vault with a pre-existing chef server and 3 nodes in AWS
  - I have not made demo 3 self-service at this point
- vault-demo-4 : Use chef-vault in a self-contained testing environment

The purpose of every cookbook is :
- create `/home/ubuntu/.s3cfg` with AWS access keys
- create `/home/ubuntu/minikitten.png` using those keys

The first two examples are meant to build a bit of familiarity with data bags and encrypted data bags so the vault stuff makes more sense.

## Set up for testing and demonstration

- Have ChefDK installed
- Clone this repo, then `cd` to the top level
- Examples 1 & 2 run a lot faster using `inspec` and `kitchen-dokken`. To use them w/ \*nix system, make sure you have `kitchen-inspec` version 0.12.1 or greater, and set: ```
export KITCHEN_LOCAL_YAML=.kitchen.dokken.yml
```
  - Setting up Docker and kitchen-dokken is out of scope of this README


## 1: Use a data bag

Set up to use v1 with:

```
rake v1
pushd cookbooks/vault-demo
```

Let's look at how we use a Chef data bag with a template in a recipe:

```
more templates/default/s3cfg.rb
more recipes/default.rb

In the recipe we've replaced the variable assignments with a fetch from a data bag:

```ruby
aws = data_bag_item('cleartext', 'aws')
aws_secret_key = aws['aws_secret_key']
aws_access_key = aws['aws_access_key']
```

and we have input JSON representation of our data, at `chef-vault-demo/inputs/aws.json` with contents:

```javascript
{
  "id": "aws",
  "aws_access_key": "AKIAJWLDGDWB6HVRMRAQ",
  "aws_secret_key": "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"
}
```

For our test we'll create the data bag inside our repo then use it with test-kitchen

```shell
knife data bag -z create cleartext
knife data bag -z from file cleartext ../../inputs/aws.json
```

Now test with test kitchen  

```
kitchen converge
kitchen verify
```

Review: What just happened here?


## 2: Encrypted data bags

```
cd cookbooks/vault-demo-v0.2.0
```

Make the secret from random data

```
mkdir -p files/default/
openssl rand -base64 512 |
  tr -d '\r\n' > files/default/encrypted_data_bag_secret
```

For testing, we'll use the `-z`option to `knife` for local-mode operations (a.k.a 'chef-zero'). To create an encrypted data bag from our cleartext `aws.json`:

```
knife data bag -z create encrypted
knife data bag -z from file encrypted data_bags/cleartext/aws.json --secret-file files/default/encrypted_data_bag_secret
```

and we'll update our recipe....



### 2.99 Refresh everything for vault demo (for demonstrators)

```
chef-server-ctl org-delete nightwatch

## Optional if we want to demonstration user creation:
for user in starly jsnow jslynt; do
  chef-server-ctl user-delete $user
done
```

## 3: Chef Vault


Using vault with test-kitchen and chef-zero/local-mode requires some amount of setup of `test fixtures`, as demonstrated in the `chef-vault` cookbook. However, since looking at the client-server interaction is important to understanding Chef Vault, we'll use a real Chef Server for the rest of this walk-through.

### 3.0: Set up the chef-server users and orgs

*Screencast: https://s3-us-west-2.amazonaws.com/chef-vault-demo/ChefVault3.0SettingUpChefServer.mp4*

On a chef-server, we'll need to:
- create an `organization`, "nightwatch"
- associate my user, `pdb`, with that organization
- create three users, 'jsnow' and 'starly' for that organization
  - and be sure to save all the relevant keys

To wit:

```
# If we need to (re-)create users:

chef-server-ctl user-create jsnow Jon Snow \
  jsnow@castleblack.we winteriscoming -f jsnow.pem
chef-server-ctl user-create starly Sam Tarly \
  starly@castleblack.we firstinbattle -f starly.pem
chef-server-ctl user-create jslynt Janos Slynt \
  jslynt@castleblack.we notmentioned -f jslynt.pem

# Set the initial admin user: (pdb for me)
myuser=pdb
chef-server-ctl org-create nightwatch Nightwatch -f nightwatch.pem -a $myuser

# Associate other users with the org:
chef-server-ctl org-user-add nightwatch jsnow --admin
chef-server-ctl org-user-add nightwatch starly
chef-server-ctl org-user-add nightwatch jslynt
```

Let's make sure to fetch the _validator.pem_ key for the nightwatch org

```
mychefserver="ubuntu@chefserver.cheffian.com"
for pem in nightwatch; do
  scp $mychefserver:$pem.pem .
done
```

To use this org I have my `.chef/knife.rb` set up to use the CHEF_SERVER env var, like this:

```
export CHEF_SERVER=nightwatch
```

Now I can test that we're all connected:

```
knife user list
```

### 3.1: Create the vault

*Screencast https://s3-us-west-2.amazonaws.com/chef-vault-demo/ChefVault3.1CreateVault.mp4*

Let's create a vault to store our credentials:

```
knife vault create \
  credentials \
  aws \
  -A starly,jsnow \
  -M client \
  -S 'name:whitewalker_node_*' \
  -J data_bags/cleartext/aws.json
```

Returns:

```
WARNING: No clients were returned from search, you may not have got what you expected!!
```

Unpack what each of the arguments are...

What have we done here? Let's look:

```
knife vault show credentials aws -M client
# compare to non-admin user
CHEF_USER=jslynt knife vault show credentials aws -M client
```

Under the covers, chef-vault is just some client-side code on top of data bags. First, let's look at the data bag item `credentials/aws`, then `credentials/aws_keys`

```
knife data bag show credentials aws
knife data bag show credentials aws_keys
```

## 3.2: Let's use vault in our code

Use: `rake v3` to link to correct code, and populate the array of nodes:


*Screencast https://s3-us-west-2.amazonaws.com/chef-vault-demo/ChefVault3.2UseInRecipe.mp4*

To the cookbook's `metadata.rb` add `depends 'chef-vault'` and to default recipe, we'll now have:

```
# install gem and stuff
chef_gem 'chef-vault' do
  compile_time true
  version '2.6.1'
end

require 'chef-vault'

# fetch the aws item from the credentials vault
# was: aws = data_bag_item('encrypted', 'aws', '/etc/chef/secret-file')
aws = chef_vault_item('credentials', 'aws')
aws_secret_key = aws['aws_secret_key']
aws_access_key = aws['aws_access_key']
```

**Upload to server**

```
berks install
berks upload
```

## 3.3 Demonstrate with server

We'll use TK test-kitchen Vagrant instances for this demonstration, to cover the following scenarios
* An instance, 'fresh', which is allocated and running, but has yet to be provisioned with Chef or joined to a Chef Server
  * For this instance, we'll use the `--vault-bootstrap` option to successfully converge
* An instance, 'autoscale', which uses the validation.pem to join the Chef Server org and attempts to
  * For this instance, we'll need to refresh the vault before a second converge can succeed

### 3.3.1 fresh

```
kitchen converge fresh
freshport=$(perl -ne 'm/port: .(\d+)/ && print $1' .kitchen/fresh-ubuntu-1404.yml)

knife bootstrap 127.0.0.1 --ssh-port $freshport \
  -N whitewalker_node_0 \
  -r 'recipe[vault-demo]' \
  --bootstrap-vault-item 'credentials:aws' \
  --sudo -x vagrant -P vagrant

kitchen verify fresh
```

############## START HERE AGAIN #############


Here are the steps we'll run through:

- Bootstrap a node with no run_list
- Try a run_list on that node before we've updated vault
- Update the vault
- Converge the node to the run_list
- Verify


#### 3.3.1. Bootstrap to run_list vault-demo:

```
# confirm we have nodes with ips:
vault-demo-ids; vault-demo-ips

NODE=0
knife bootstrap ${VAULT_IPS[$NODE]} \
  -N whitewalker_node_$NODE \
  --hint ec2 \
  -r 'recipe[vault-demo]' \
  --sudo -x ubuntu

# Oops ^^ this fails

```

#### 3.3.2. Why did it fail? How to fix it...

```
knife node list
knife data bag show credentials aws_keys
knife vault refresh credentials aws -M client
knife data bag show credentials aws_keys
```

#### 3.3.3. Attempt again to converge node to a run_list

```
knife ssh 'name:white*' -x ubuntu 'sudo chef-client'
```

#### 3.3.4. Verify

```
SPEC=$HOME/Projects/pburkholder/chef-vault-demo/cookbooks/vault-demo/test/integration/default/serverspec/default_spec.rb
inspec exec $SPEC --key-files  ~/.ssh/pburkholder-one -t ssh://ubuntu@${VAULT_IPS[$NODE]}
```

## 3.4 Demonstrate node bootstrap with --vault-bootstrap

For our second node, VAULT_IPS[1], we'll use the `--vault-bootstrap` option so

```
NODE=1
knife bootstrap ${VAULT_IPS[$NODE]} \
  -N whitewalker_node_${NODE} \
  --hint ec2 \
  -r 'recipe[vault-demo]'    \
  --bootstrap-vault-item 'credentials:aws' \
  --sudo -x ubuntu
```

Now view the vault and verify the result.:

```
knife data bag show credentials aws_keys
inspec exec $SPEC --key-files  ~/.ssh/pburkholder-one -t ssh://ubuntu@${VAULT_IPS[$NODE]}
```


## 4 Working with Vault

### 4.1 How to work with vault over time

#### 4.1.1 Updating vault items

Use: `rake v4` to link to correct code

Let's add some new secret fields to our template -- per the code in

- cookbooks/vault-demo/templates/default/s3cfg.erb
- cookbooks/vault-demo/recipes/default.rb

we will add a `aws_comment` to the .s3cfg file.

We can upload that cookbook and run the chef-client on our nodes and test the results:

```
(cd cookbooks/vault-demo/ && berks install && berks upload)
knife ssh 'name:white*' -x ubuntu 'sudo chef-client'
NODE=0
inspec exec $SPEC --key-files ~/.ssh/pburkholder-one -t ssh://ubuntu@${VAULT_IPS[$NODE]}
```

So we get the failures we expect. To fix that, we need to update our vault.

```
knife vault edit credentials aws -M client
```

Now we can run that converge and test again (note no update to cookbook needed)

```
knife ssh 'name:white*' -x ubuntu 'sudo chef-client'
NODE=0
inspec exec $SPEC --key-files ~/.ssh/pburkholder-one -t ssh://ubuntu@${VAULT_IPS[$NODE]}
```

Other management tasks are covered in the documentation such as:
- adding nodes
- removing nodes
- updating admin keys
- adding admins
- removing admins
- deleting a vault item
- deleting an entire vault (which is a delete command to `data bag`)

#### 4.1.2 Vault and version control considerations

Your vault credentials are recoverable from backup if you make sure to store the entire data bag AND have access to at least one of the admin private keys. To track in a VCS you'd need to have a representation that is safe to store, and can be recovered to that point in time. How might that work?

The following gives us the clear-text representation of the vault item credentials:aws:

```
> knife vault show credentials aws -M client -F json
{
  "id": "aws",
  "aws_access_key": "AKIAJWLDGDWB6HVRMRAQ",
  "aws_secret_key": "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"
}
```

Clearly we can't commit the clear-test to version control. How about the encrypted data bag representation?

```
> knife data bag show credentials aws -F json
WARNING: Encrypted data bag detected, but no secret provided for decoding.  Displaying encrypted data.
{
  "id": "aws",
  "aws_access_key": {
    "encrypted_data": "nHwnGE8bMm/6ECg6IXsBskv1SdW/PoptPKugToy+LGVgfMVvX3T4jSXp/Axk\nOZMv\n",
    "iv": "OpUENg6SgR68A7M4QwCACQ==\n",
    "version": 1,
    "cipher": "aes-256-cbc"
  },
  "aws_secret_key": {
    "encrypted_data": "BJOhvFid4TXX0I9075rBbS5XetTFZAc3O0JMWDSB8MOpwsN6UPrpTtHSQcSF\n79h9SimKiDqRyIgMWJFOWkzPUQ==\n",
    "iv": "xPtZIrNvrBFjQ4AcJzeIgQ==\n",
    "version": 1,
    "cipher": "aes-256-cbc"
  }
}
```

That's OK to commit to version control, but is it of any use?
- If you want to simply track when credentials changed, yes
- If you want to recover those credentials later, no

The encrypted credentials are recoverable only if you have the symmetric key. To get the symmetric key, you need two things:

- The contents of `aws_keys`
- The private key of one of the admins from the time when vault was last refreshed.

**or**
- you can get the admin's encrypted copy of the symmetric key:

```
> knife data bag show credentials aws_keys -F json | jq '.pdb'
"WkGmb+I6WgE9lBdphbmroIPS73JQ52d4Dlt77WWHGIhpNdOpTjbyy59Lvzwj\n7plgzsKkGReXcrq1+wTm1jSQbjKyo5/Q2GuYCXgEKMJsYu4u7Qfvo901aq9l\nOD/ljmVGRfK945fOuSEmHB5u1Hy1Ql1KdE6jQEnIPLTEuZxJ+9ozEtL6sjkY\n7Oh/2AlvhMW2xyEoVnssT9NZFAVlyBxlspXbqZS+D8BUT9l5DRs6ZOsnCgGM\nlvlzdC/jOzDnuczMXATGKSfL41Smfn32UBmaA8tIvmNkoN+DYd/3i4W3MaTT\nR/21Rs1wkMy88GJt7HiMopSa8T2UgVosBMAYIJwA1g==\n"
```

- then decrypt that key with the admins private key
- and store the symmetric key someplace safe (outside of version control)

In short, there's nothing in the standard Chef workflow that works for version control of a Chef Vault, but there are workflows that use other PKI elements that work. See, for example, [http://padgeblog.com/2015/03/24/chef-vault-with-large-teams/](Chef Vault with Large Teams) by JP Padgett.


### 4.2 Some weaknesses to watch for

- autoscaling
- node impersonation attack
- data-bag write-lock issues
- large client pools
- vault-admins not the same set of folks as the chef-admins

## 5 - Images:

### 5.1 Encrypted Data Bag

![Encrypted Data Bag](./inputs/edb.png)

### 5.2 Vault and Encrypted Data Bags

![Vault and Data Bags](./inputs/vault.png)

## Notes on presenting

Order:
1. Present: Using DBs and EDBs
  1. Part 2 with databags
  2. Part 3 with EDBs
1. skip: Setting up server
1. Screencast: 4.0.1CreateVault
2. Present: 4.1 Using in Recipe
1. Present: 4.2 First test starting with no run_list node
1. Present: 4.3 Using knife bootstrap


### 99: Set up our test instances (an aside on AWS provisioning)

To use this we need some nodes. The cookbook `vault-provision` creates an AWS autoscale group with TKTK nodes, and pre-installs `chef-client` on them. I use the cookbook to stand up the nodes like this:

```
export AWS_DEFAULT_PROFILE=default
chef-client -z cookbooks/vault-provision/recipes/ws_autoscaling.rb
```

```
function vault-demo-ids() {
 aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names vault-provision | jq -r '[.AutoScalingGroups[].Instances[].InstanceId] | join(" ")'
}


function vault-demo-ips() {
  instance_ids=$(vault-demo-ids)
  aws ec2 describe-instances --instance-ids $instance_ids | jq -r '.Reservations[].Instances[].PublicIpAddress'
}

alias terminate-vault-id='aws autoscaling terminate-instance-in-auto-scaling-group --no-should-decrement-desired-capacity --instance-id '  
}

VAULT_IPS=( $(vault-demo-ips) )
VAULT_IDS=( $(vault-demo-ids) )
```

## Set and Overview (Optional)

- The scenario of fetching from AWS
- The test suites
- Initial run with cleartext data bag
- Run with encrypted_data bag
- Vault creation
- Using vault

## Some of the prerequisites (for demonstrators/contributors only)

- I've created an s3 bucket, `s3://chef-vault-demo` that has two objects,
  - unikitten.png (1.7Mb)
  - minikitten.png (417Kb)
- I've created an AWS user, `chef-vault-demo` which has the following policy applied, so it can do nothing except GET those objects
```
Show Policy
 {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1454343707000",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::chef-vault-demo/unikitten.png",
                "arn:aws:s3:::chef-vault-demo/minikitten.png"
            ]
        }
    ]
}
```
