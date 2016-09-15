package 'openssh' do
  package_name node['ssh']['package']
  action :install
end

cookbook_file 'sshrc' do
  path '/etc/ssh/sshrc'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
end

service 'openssh' do
  service_name node['ssh']['service']
  supports :status => true, :restart => true, :reload => true
  action [ :enable, :start ]
end
