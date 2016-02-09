# -*- encoding: utf-8 -*-

desc "Link .kitchen.local.yml for Dokken"
task :dokken do
  File.symlink('_kitchen.local.yml', '.kitchen.local.yml')
end

desc "Set up links to demo 0.3 vault recipe"
task :v3 do
  File.symlink(File.absolute_path('./cookbooks/vault-demo-v0.3.0'),  File.absolute_path('./cookbooks/vault-demo'))
end

desc "Set up links to demo 0.4 vault management stuff"
task :v4 do
  File.symlink(File.absolute_path('./cookbooks/vault-demo-v0.4.0'),  File.absolute_path('./cookbooks/vault-demo'))
end
