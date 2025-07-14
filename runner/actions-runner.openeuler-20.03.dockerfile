FROM openeuler/openeuler:20.03

ARG TARGETPLATFORM
ARG RUNNER_VERSION
ARG RUNNER_CONTAINER_HOOKS_VERSION
ARG CHANNEL=stable
ARG DUMB_INIT_VERSION=1.2.5
ARG RUNNER_USER_UID=1001

RUN yum clean all && yum makecache
RUN yum install -y \
    rpm-build gcc gcc-c++ autoconf automake libtool systemd-units openssl openssl-devel \
    python3-devel desktop-file-utils groff graphviz checkpolicy selinux-policy-devel \
    python3-sphinx libbpf-devel unbound unbound-devel python3-six python3-sortedcontainers \
    rdma-core-devel numactl-devel libpcap-devel systemtap-sdt-devel jq git unzip

RUN yum install -y sudo meson python3-pyelftools doxygen zlib-devel

RUN python3 -m pip install meson==0.60.0
# Download latest git-lfs version
#RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.rpm.sh | os=el dist=7 sudo -E bash
#RUN yum -y install git-lfs

# kubectl
#RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
#    && curl -fLo /usr/bin/kubectl https://dl.k8s.io/release/v1.26.0/bin/linux/${ARCH}/kubectl \
#    && chmod +x /usr/bin/kubectl

# Runner user
RUN adduser --uid $RUNNER_USER_UID runner \
    && usermod -aG wheel runner \
    && echo "%wheel   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers

ENV HOME=/home/runner
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/bin/dumb-init

ENV RUNNER_ASSETS_DIR=/runnertmp
RUN touch /etc/redhat-release
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm -f runner.tar.gz \
    && ./bin/installdependencies.sh \
    && yum install -y libyaml-devel

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && rpm -Uvh https://repo.openeuler.org/openEuler-22.03-LTS/OS/${ARCH}/Packages/autoconf-2.71-2.oe2203.noarch.rpm


ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache

RUN cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm -f runner-container-hooks.zip

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY entrypoint.sh startup.sh logger.sh wait.sh graceful-stop.sh update-status /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh /usr/bin/startup.sh

# Configure hooks folder structure.
COPY hooks /etc/arc/hooks/

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV ImageOS=openeuler2003

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

RUN sed -i 's/%dist %{nil}/%dist .oe1/g' /etc/rpm/macros.dist

RUN yum clean all

USER runner
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]
