#!/bin/bash
# Run build process in docker container

set -ex -o pipefail
SCRIPT_DIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)"

CID=
docker_rm() {
  if [[ -z "${CID}" ]]; then
    return 0
  fi
  if [[ -n "$LEAVE_CONTAINER" ]]; then
     if [[ "${LEAVE_CONTAINER}" != "0" ]]; then
        echo "Skip to clean container: ${CID}"
        return 0
     fi
  fi
  docker rm -f "${CID}" || :
}
trap 'docker_rm' EXIT

check_file_path() {
  local file_path=$1 type=$2
  case "${type}" in
    "remove_suffix")
    if [[ -n "${file_path}" && ! -f "${file_path}" && ! -f "${file_path%.*}" ]]; then
      echo "ERROR: Can't find the file: ${file_path} or ${file_path%.*}" >&2
      exit 1
    fi
    ;;
    "flag")
    FILE_EXISTS=
    if [[ -n "${file_path}" && -f "${file_path}" ]]; then
       FILE_EXISTS=true
    fi
    ;;
    *)
    if [[ -n "${file_path}" && ! -f "${file_path}" ]]; then
      echo "ERROR: Can't find the file: ${file_path}" >&2
      exit 1
    fi
    ;;
  esac
}

exclude_comment_lines() {
  local file_path=$1
  cat ${file_path} | grep -v '^#' | sed -e 's/#.*//g' | sed '/^$/d'
}

BUILD_ENV_PATH=${1:?"ERROR: env file is not given."}
check_file_path ${BUILD_ENV_PATH}

STEP_DIR_NAME=${2:?"ERROR: step directory is not given."}
STEP_DIR=${SCRIPT_DIR}/${STEP_DIR_NAME}
if [[ -n "${STEP_DIR_NAME}" && ! -d "${STEP_DIR}" ]]; then
  if [[ -n "${STEP_DIR_NAME}" && -d "${STEP_DIR%.*}" ]]; then
    STEP_DIR_NAME=${STEP_DIR_NAME%.*}
    STEP_DIR=${STEP_DIR%.*}
  else
    echo "ERROR: Can't file the directory: ${STEP_DIR}" >&2
    exit 1
  fi
fi

set -a
. ${BUILD_ENV_PATH}
set +a

if [[ -n "$JENKINS_HOME" ]]; then
  # wakame-vdc-shinbashi/branch1/el7
  img_tag=$(echo "build.${JOB_NAME}/${BUILD_OS}" | tr '/' '.')
else
  img_tag="build.wakame-vdc-shinbashi.$(git rev-parse --abbrev-ref HEAD).${BUILD_OS}"
fi
# Docker 1.10 fails with uppercase image tag name. need letter case translation.
# https://github.com/docker/docker/issues/20056
img_tag="${img_tag,,}"

STEP_SCRIPT_PATH=${STEP_DIR}/build.sh

# Check the build.sh
check_file_path ${STEP_SCRIPT_PATH}
# Check the Dockerfile.
# Naming conventions: Dockerfile.el7, Dockerfile.
DOCKER_FILE_PATH=${STEP_DIR}/Dockerfile.${BUILD_OS}
check_file_path ${DOCKER_FILE_PATH} 'remove_suffix'
if [[ ! -f "${DOCKER_FILE_PATH}" && -f "${DOCKER_FILE_PATH%.*}" ]]; then
  DOCKER_FILE_PATH=${DOCKER_FILE_PATH%.*}
fi

# Create Docker container image from Dockerfile.
docker build \
  ${GITHUB_TOKEN:+--build-arg "GITHUB_TOKEN=${GITHUB_TOKEN}"} \
  ${REPO_BASE_URL:+--build-arg "REPO_BASE_URL=${REPO_BASE_URL}"} \
  ${BRANCH:+--build-arg "BRANCH=${BRANCH}"} \
   -t "${img_tag}" -f "${DOCKER_FILE_PATH}" .

# Create artifact directory
ARTIFACT_DIR=/mnt/jenkins/artifact/${BRANCH_NAME}/${RELEASE_SUFFIX}
[[ -d ${ARTIFACT_DIR} ]] || { mkdir -p ${ARTIFACT_DIR}; }

# Run Docker container from create image.
DOCKER_ARTIFACT_DIR=/mnt/artifact
WORKDIR=$(docker inspect --type=image --format='{{ .Config.WorkingDir }}' "${img_tag}")
if [[ -z "${WORKDIR}" ]]; then
  echo "ERROR: Dockerfile misses WORKDIR parameter" >&2
  exit 1
fi

# Use host network when run integration test.
if [[ "${BUILD_STAGE}" = "integration" ]]; then
  HOSTNET="--net=host"
fi

CID=$(docker run ${HOSTNET} --privileged -v ${ARTIFACT_DIR}:${DOCKER_ARTIFACT_DIR}:rw ${GITHUB_TOKEN:+--env "GITHUB_TOKEN=${GITHUB_TOKEN}"} --env-file=${BUILD_ENV_PATH} -id "${img_tag}" /sbin/init)

# Upload current directory to container

(
  POSTBUILD_SCRIPT_PATH=${STEP_DIR}/post_build.sh
  FAILUREBUILD_SCRIPT_PATH=${STEP_DIR}/failure_build.sh
  SUCCESSBUILD_SCRIPT_PATH=${STEP_DIR}/success_build.sh

  docker_exec() {
    local build_script_path=$1
    check_file_path ${build_script_path} 'flag'
    if [[ ${FILE_EXISTS} ]]; then
      docker exec ${CID} /bin/bash -c "ci/${STEP_DIR_NAME}/${build_script_path##*/}"
    fi
  }

  exec_post_build() {
    docker_exec ${POSTBUILD_SCRIPT_PATH}
  }
  trap 'exec_post_build' EXIT

  exec_failure_build() {
    docker_exec ${FAILUREBUILD_SCRIPT_PATH}
  }
  trap 'exec_failure_build' ERR

  # Exec script
  docker exec ${CID} /bin/bash -c "ci/${STEP_DIR_NAME}/build.sh"

  # exec success build
  docker_exec ${SUCCESSBUILD_SCRIPT_PATH}
)

