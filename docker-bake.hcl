group default {
  targets = ["actions-runner-dind-ubuntu-22-04"]
}

group openeuler {
  targets = ["actions-runner-openeuler-20-03"]
}

group tencentos {
  targets = ["actions-runner-tencentos-3"]
}

group centos {
  targets = ["actions-runner-centos-7"]
}

variable TAG_SUFFIX { default = "latest" }
variable RUNNER_VERSION { default = "2.332.0" }
variable RUNNER_CONTAINER_HOOKS_VERSION { default = "0.8.1" }
variable DOCKER_VERSION { default = "24.0.7" }

target actions-runner-dind-ubuntu-22-04 {
  context     = "runner/"
  contexts = {
    "ubuntu:18.04" = "docker-image://registry.smtx.io/sdn-base/ubuntu:18.04"
    "ubuntu:20.04" = "docker-image://registry.smtx.io/sdn-base/ubuntu:20.04"
    "ubuntu:22.04" = "docker-image://registry.smtx.io/sdn-base/ubuntu:22.04"
    "ubuntu:24.04" = "docker-image://registry.smtx.io/sdn-base/ubuntu:24.04"
  }
  dockerfile = "actions-runner-dind.ubuntu-22.04.dockerfile"
  args = {
    TARGETPLATFORM                 = "linux/amd64"
    RUNNER_VERSION                 = RUNNER_VERSION
    RUNNER_CONTAINER_HOOKS_VERSION = RUNNER_CONTAINER_HOOKS_VERSION
    DOCKER_VERSION                 = DOCKER_VERSION
  }
  tags      = ["registry.smtx.io/everoute/summerwind/actions-runner-dind:ubuntu-22.04-buildx-${TAG_SUFFIX}"]
  platforms = ["linux/amd64"]
  output    = ["type=registry"]
}

target actions-runner-openeuler-20-03 {
  context     = "runner/"
  contexts = {
  }
  dockerfile = "actions-runner.openeuler-20.03.dockerfile"
  args = {
    RUNNER_VERSION                 = RUNNER_VERSION
    RUNNER_CONTAINER_HOOKS_VERSION = RUNNER_CONTAINER_HOOKS_VERSION
  }
  tags      = ["registry.smtx.io/action-runner/openeuler-20.03:${TAG_SUFFIX}"]
  platforms = ["linux/amd64","linux/arm64"]
  output    = ["type=registry"]
}

target actions-runner-tencentos-3 {
  context     = "runner/"
  contexts = {
  }
  dockerfile = "actions-runner.tencentos-3.dockerfile"
  args = {
    RUNNER_VERSION                 = RUNNER_VERSION
    RUNNER_CONTAINER_HOOKS_VERSION = RUNNER_CONTAINER_HOOKS_VERSION
  }
  tags      = ["registry.smtx.io/action-runner/tencentos-3:${TAG_SUFFIX}"]
  platforms = ["linux/amd64","linux/arm64"]
  output    = ["type=registry"]
}

target actions-runner-centos-7 {
  context     = "runner/"
  ulimits = [
    "nofile=1048576:1048576"
  ]
  dockerfile = "actions-runner.centos-7.dockerfile"
  args = {
    RUNNER_VERSION                 = RUNNER_VERSION
    RUNNER_CONTAINER_HOOKS_VERSION = RUNNER_CONTAINER_HOOKS_VERSION
  }
  tags      = ["registry.smtx.io/action-runner/centos-7:${TAG_SUFFIX}"]
  platforms = ["linux/amd64"]
  output    = ["type=registry"]
}

