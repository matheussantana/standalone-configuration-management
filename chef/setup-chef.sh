#!/bin/bash

usage() {
    echo "Usage: $0 -e EMAIL_ADDRESS (as root)"
    exit 1
}

install_deps() {
    if [ -f '/etc/debian_version' ] ; then
        pm="apt-get -y"
    elif [ -f '/etc/redhat-release' ] ; then
        pm="yum -y"
    elif [ -f '/etc/SuSE-release' ] ; then
        pm="zypper -n"
    fi
    $pm install git curl
}

get_config_from_github() {
  tmp_dir=$(mktemp -d)
  git clone https://github.com/furlongm/standalone-configuration-management ${tmp_dir}
  cp -r ${tmp_dir}/chef /srv
  rm -fr ${tmp_dir}
}

main() {
  curl -L https://www.chef.io/chef/install.sh | sudo bash || exit 1
  get_config_from_github
  #sed -i -e "s/admin@example.com/${email}/" /srv/chef/postfix/init.sls
  chef-solo -c /srv/chef/solo.rb
}

while getopts ":e:" opt ; do
  case ${opt} in
    e)
      email=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z ${email} || ${EUID} -ne 0 ]] ; then
    usage
else
    which git 1>/dev/null 2>&1 || install_deps
    which curl 1>/dev/null 2>&1 || install_deps
    main
fi