#!/bin/bash

usage() {
    echo "Usage: $0 -e EMAIL_ADDRESS (as root)"
    exit 1
}

get_pm() {
    if [ -f '/etc/debian_version' ] ; then
        pm="apt-get -y"
        ${pm} update 
    elif [ -f '/etc/redhat-release' ] ; then
        pm="yum -y"
        ${pm} makecache
    elif [ -f '/etc/SuSE-release' ] ; then
        pm="zypper -n"
        ${pm} refresh
    fi
}

install_deps() {
    ${pm} install git curl
}

install_puppet() {
    if [ -f '/etc/debian_version' ] ; then
        . /etc/os-release
        if [ ${ID} == "ubuntu" ] ; then
            if [ ! -z ${UBUNTU_CODENAME} ] ; then
                codename=${UBUNTU_CODENAME}
            else
                codename='trusty'
            fi
        else
            codename=$(echo ${VERSION} | sed -e "s/.*(\(.*\))/\1/")
        fi
        if [ "${codename}" != "xenial" ] ; then
            puppet_deb=puppetlabs-release-${codename}.deb
            curl -O https://apt.puppetlabs.com/${puppet_deb}
            dpkg -i ${puppet_deb}
            rm -f ${puppet_deb}
        fi
        ${pm} update
    elif [ -f '/etc/redhat-release' ] ; then
        ${pm} install http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
    fi
    ${pm} install puppet
}

install_vim_syntax_highlighting() {
    if [ ! -z "${SUDO_UID}" ] ; then
        home=$(getent passwd ${SUDO_UID} | cut -d \: -f 6)
    else
        home=~
    fi
    for i in ftdetect ftplugin indent syntax ; do
        if [ -f ${home}/.vim/${i}/puppet.vim ] ; then
            return
        fi
    done
    tmp_dir=$(mktemp -d)
    mkdir -p ${home}/.vim
    git clone https://github.com/puppetlabs/puppet-syntax-vim.git ${tmp_dir}
    cp -r ${tmp_dir}/* ${home}/.vim/
    if [ ! -z "${SUDO_UID}" ] ; then
        chown -R ${SUDO_UID}:${SUDO_GID} ${home}/.vim
    fi
    rm -fr ${tmp_dir}
}

get_config_from_github() {
    tmp_dir=$(mktemp -d)
    git clone https://github.com/furlongm/standalone-configuration-management ${tmp_dir}
    mkdir -p /etc/puppet/{manifests,modules}
    cp -r ${tmp_dir}/puppet/modules/* /etc/puppet/modules
    cp -r ${tmp_dir}/puppet/manifests/* /etc/puppet/manifests
    rm -fr ${tmp_dir}
}

main() {
    get_pm
    which git 1>/dev/null 2>&1 || install_deps
    which curl 1>/dev/null 2>&1 || install_deps
    which puppet 1>/dev/null 2>&1 || install_puppet
    install_vim_syntax_highlighting
    if [ "${run_path}" != "." ] ; then
        run_path=/etc/puppet
        get_config_from_github
    fi
    sed -i -e "s/admin@example.com/${email}/" ${run_path}/manifests/standalone-site.pp
    puppet apply --show_diff --modulepath ${run_path}/modules ${run_path}/manifests/standalone-site.pp
}

while getopts ":le:" opt ; do
    case ${opt} in
        e)
            email=${OPTARG}
            ;;
        l)
            run_path=.
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z ${email} || ${EUID} -ne 0 ]] ; then
    usage
fi
main
