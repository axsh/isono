#!/bin/bash

BUILD_ENV_PATH=${1:?"ERROR: env file is not given."}

if [[ -n "${BUILD_ENV_PATH}" && ! -f "${BUILD_ENV_PATH}" ]]; then
  echo "ERROR: Cant't find the file: ${BUILD_ENV_PATH}" >&2
  exit 1
fi

set -a
. ${BUILD_ENV_PATH}
set +a

GEM_DIR=/mnt/jenkins/gems/isono/${BRANCH}
ARTIFACT_DIR=/mnt/jenkins/artifact/${BRANCH}/${RELEASE_SUFFIX}

[[ -d ${GEM_DIR} ]] || mkdir -p ${GEM_DIR}
[[ -d ${ARTIFACT_DIR} ]] && cp -r ${ARTIFACT_DIR}/isono-*.gem ${GEM_DIR}/

