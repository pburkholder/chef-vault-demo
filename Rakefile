# -*- encoding: utf-8 -*-

#desc "Link .kitchen.local.yml for Dokken"
#task :dokken do
#  File.symlink('_kitchen.local.yml', '.kitchen.local.yml')
#end

def vault_link(version)
  File.unlink('./cookbooks/vault-demo')
  File.symlink(
    File.absolute_path("./cookbooks/vault-demo-v#{version}"),
    File.absolute_path('./cookbooks/vault-demo')
  )
end

desc "Set up links to demo 0.1 vault recipe"
task :v1 do
  vault_link('0.1.0')
end

desc "Set up links to demo 0.2 vault recipe"
task :v2 do
  vault_link('0.2.0')
end

desc "Set up links to demo 0.3 vault recipe"
task :v3 do
  vault_link('0.3.0')
end

desc "Set up links to demo 0.4 vault management stuff"
task :v4 do
  vault_link('0.4.0')
end
