# chef_vault_demo

TODO: Enter the cookbook description here.

# First let's create a data bag, in clear text

```
knife data bag create clear_db # create the clear_text data bag
knife data bag from file clear_db clear_text.json # populate that DB
knife data bag show -f json clear_db
```

# Now let's do an encrypted data bag

```
knife data bag create encrypted_db --secret-file secret
knife data bag from file encrypted_db edb_text.json --secret-file secret     
knife data bag show encrypted_db -f json                                           
knife data bag show encrypted_db -f json --secret-file secret
```

# Create a chef vault

(Note for windows/conemu: Ctrl-V pastes single line, Shift-Insert (Shift-Fn-Enter on Apple keyboard))

```
knife vault create vault_demo vault_text `
    -m client --json vault_text.json `
    -A "pburkholder-getchef-com" -S "name:chefvault*"
# other options for -S could be 'role:webserver'

knife data bag show vault_demo -f json     
knife data bag show vault_demo vault_text -f json        
knife data bag show vault_demo vault_text_keys -f json                                      


```

# Bootstrapping into chefvault

(Note for Windows: You'll need to load the Powershell Module 'chef',
per the 12.4.0 release notes, or all the quoting is wrong)

```
knife bootstrap 54.210.205.192 `
  --bootstrap-vault-json '{"vault_demo":["vault_text"]}' `
  -N chefvaultdemo --hint ec2 -r '' `
  --sudo -x ec2-user -i ~/.ssh/pburkholder-one.pem
```

# Notes for getting things to work in Windows

Add to $PROFILE

```
$env:PsModulePath += ";c:\opscode\chefdk\modules"

$env:Path += ";" + (Get-Item "Env:ProgramFiles(x86)").Value + "\Git\bin"
```

Then `import-module chef` to fix quoting issues

And now you have `ssh` and `ssh-agent` available to you.
