#!/bin/bash -e

# setup wakame-vdc 3rd repo
if [ -n "${REPO_BASE_URL}" ]; then
  echo "${REPO_BASE_URL}" > /etc/yum/vars/repo_base_url
  cat <<EOF > /etc/yum.repos.d/wakame-vdc.repo
[wakame-vdc-3rd]
name=Wakame-vdc Shinbashi 3rd Repo - devrepo
baseurl=\$repo_base_url/3rd-repos/master
enabled=1
gpgcheck=0
EOF
  yum repolist
  yum install -y wakame-vdc-ruby
fi

