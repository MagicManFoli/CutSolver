#!/bin/bash
# (c) Artur.Klauser@computer.org
#
# This script installs support for building multi-architecture docker images
# with docker buildx on CI/CD pipelines like Github Actions or Travis. It is
# assumed that you start of with a fresh VM every time you run this and have to
# install everything necessary to support 'docker buildx build' from scratch.
#
# Example usage in Travis stage:
#
# jobs:
#   include:
#     - stage: Deploy docker image
#       script:
#         - source ./multi-arch-docker-ci.sh
#         - set -ex; multi_arch_docker::main; set +x
#
# More information about Linux environment constraints can be found at:
# https://nexus.eddiesinentropy.net/2020/01/12/Building-Multi-architecture-Docker-Images-With-Buildx/

function _version() {
  printf '%02d' $(echo "$1" | tr . ' ' | sed -e 's/ 0*/ /g') 2>/dev/null
}

function multi_arch_docker::install_docker_buildx() {
  # Check kernel version.
  local -r kernel_version="$(uname -r)"
  if [[ "$(_version "$kernel_version")" < "$(_version '4.8')" ]]; then
    echo "Kernel $kernel_version too old - need >= 4.8."
    exit 1
  fi

  # Install up-to-date version of docker, with buildx support.
  local -r docker_apt_repo='https://download.docker.com/linux/ubuntu'
  curl -fsSL "${docker_apt_repo}/gpg" | sudo apt-key add -
  local -r os="$(lsb_release -cs)"
  sudo add-apt-repository "deb [arch=amd64] $docker_apt_repo $os stable"
  sudo apt-get update
  sudo apt-get -y -o Dpkg::Options::="--force-confnew" install docker-ce

  # Enable docker daemon experimental support (for 'docker pull --platform').
  local -r config='/etc/docker/daemon.json'
  if [[ -e "$config" ]]; then
    sudo sed -i -e 's/{/{ "experimental": true, /' "$config"
  else
    echo '{ "experimental": true }' | sudo tee "$config"
  fi
  sudo systemctl restart docker

  # Install QEMU multi-architecture support for docker buildx.
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

  # Enable docker CLI experimental support (for 'docker buildx').
  export DOCKER_CLI_EXPERIMENTAL=enabled
  # Instantiate docker buildx builder with multi-architecture support.
  docker buildx create --name mybuilder
  docker buildx use mybuilder
  # Start up buildx and verify that all is OK.
  docker buildx inspect --bootstrap
}

# Log in to Docker Hub for deployment.
# Env:
#   DOCKER_USERNAME ... user name of Docker Hub account
#   DOCKER_PASSWORD ... password of Docker Hub account
function multi_arch_docker::login_to_docker_hub() {
  echo "$DOCKERHUB_PW" | docker login -u="$DOCKERHUB_USER" --password-stdin
}

# Run buildx build and push.
# Env:
#   DOCKER_PLATFORMS ... space separated list of Docker platforms to build.
function multi_arch_docker::build_and_push() {
  docker buildx build \
    --platform "${DOCKER_PLATFORMS// /,}" \
    -t "$IMAGE_NAME:latest" -t "$IMAGE_NAME:$TRAVIS_TAG" \
    --progress plain \
    --push \
    .
}

function multi_arch_docker::main() {
  set -ex
  # Set docker platforms for which to build (careful, takes forever!)
  export DOCKER_PLATFORMS='linux/amd64'
  # DOCKER_PLATFORMS+=' linux/arm/v6'
  DOCKER_PLATFORMS+=' linux/arm/v7'
  # DOCKER_PLATFORMS+=' linux/arm64'

  export IMAGE_NAME=${DOCKERHUB_USER}/cutsolver

  multi_arch_docker::install_docker_buildx
  multi_arch_docker::login_to_docker_hub
  multi_arch_docker::build_and_push
  set +x
  return 0
}
