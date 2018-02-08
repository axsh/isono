FROM centos:6

ARG REPO_BASE_URL

COPY ci/build/fastestmirror.conf /etc/yum/pluginconf.d/
# WORKDIR creates non-exisiting path
WORKDIR /var/tmp/isono
# COPY isono workspace to WORKDIR
COPY . .
RUN ci/scripts/devtools.sh
RUN ci/scripts/wakame-vdc-ruby.sh
