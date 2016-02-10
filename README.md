# chef-vault-demo-cookbook

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
- this cookbook runs a lot faster using `inspec` and `kitchen-dokken`. The command `rake dokken` symlinks `_kitchen.local.yml` to `.kitchen.local.yml` so you can use. As of 1 Feb 2016, this required local installation of the gem from https://github.com/chef/kitchen-inspec so you can use Inspec against docker.

## 1: Use a data bag

```
git checkout v2-initial-databag
git diff origin/v1 -- recipes
git diff origin/v1 -- data_bags
```

In the recipe we've replaced the variable assignments with a fetch from a data bag:

```
aws = data_bag_item('cleartext', 'aws')
aws_secret_key = aws['aws_secret_key']
aws_access_key = aws['aws_access_key']
```

and we've now created a databag, as JSON, at data_bags/cleartext/aws.json, with contents:

```
{
  "id": "aws",
  "aws_access_key": "AKIAJWLDGDWB6HVRMRAQ",
  "aws_secret_key": "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"
}
```


```
knife data bag -z create cleartext
knife data bag -z from file cleartext data_bags/cleartext/aws.json
```

## 2: Encrypted data bags

```
git checkout v3-encrypted-databag
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

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name vault-provision \
  --desired-capacity 0

chef-server-ctl org-delete nightwatch
for user in starly jsnow jslynt; do
  chef-server-ctl user-delete $user
done

aws autoscaling set-desired-capacity \
  --auto-scaling-group-name vault-provision \
  --desired-capacity 3

```

## 3: Vault


Using vault with test-kitchen and chef-zero/local-mode requires some amount of setup of `test fixtures`, as demonstrated in the `chef-vault` cookboook. However, since looking at the client-server interaction is important to understanding Chef Vault, we'll use a real Chef Server for the rest of this walk-through.

### 3.0: Set up the chef-server users and orgs

*Screencast: https://s3-us-west-2.amazonaws.com/chef-vault-demo/ChefVault3.0SettingUpChefServer.mp4*

On a chef-server, we'll need to:
- create an `organization`, "nightwatch"
- associate my user, `pdb`, with that organization
- create three users, 'jsnow' and 'starly' for that organization
  - and be sure to save all the relevant keys

To wit:

```
myuser=pdb
chef-server-ctl org-create nightwatch Nightwatch -f nightwatch.pem -a $myuser

chef-server-ctl user-create jsnow Jon Snow \
  jsnow@castleblack.we winteriscoming -f jsnow.pem
chef-server-ctl user-create starly Sam Tarly \
  starly@castleblack.we firstinbattle -f starly.pem
chef-server-ctl user-create jslynt Janos Slynt \
  jslynt@castleblack.we notmentioned -f jslynt.pem

chef-server-ctl org-user-add nightwatch jsnow --admin
chef-server-ctl org-user-add nightwatch starly
chef-server-ctl org-user-add nightwatch jslynt
```

Let's make sure to fetch all these `.pem` files:

```
mychefserver="ubuntu@chefserver.cheffian.com"
for pem in nightwatch jsnow starly jslynt; do
  scp $mychefserver:$pem.pem $HOME/.chef/cheffian/
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

```
export VAULT_IPS=( $(vault-demo-ips) )
export VAULT_ID=( $(vault-demo-ids) )
```

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

## 3.3 Demonstrate on a node that is already a chef node

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



Let's update our vault with a new set of AWS credentials.

#### 4.1.2 Vault and version control



### 4.2 Some weaknesses to watch for

- autoscaling
- node impersonation attack
- data-bag write-lock issues
- large client pools
- vault-admins not the same set of folks as the chef-admins

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
