FROM centos:7

ARG TARGETPLATFORM
ARG RUNNER_VERSION
ARG RUNNER_CONTAINER_HOOKS_VERSION
ARG CHANNEL=stable
ARG DUMB_INIT_VERSION=1.2.5
ARG RUNNER_USER_UID=1001


RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e "s|^#baseurl=http://mirror.centos.org/centos/\$releasever|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009|g" \
    -e "s|^#baseurl=http://mirror.centos.org/\$contentdir/\$releasever|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009|g" \
    -i /etc/yum.repos.d/CentOS-*.repo; 

RUN yum clean all && yum makecache
RUN yum install -y epel-release
RUN yum install -y \
    rpm-build gcc gcc-c++ autoconf automake libtool systemd-units openssl openssl-devel \
    python3-devel desktop-file-utils groff graphviz checkpolicy selinux-policy-devel \
    python3-sphinx libbpf-devel unbound unbound-devel python3-six python3-sortedcontainers \
    rdma-core-devel numactl-devel libpcap-devel systemtap-sdt-devel jq git unzip

RUN yum install -y sudo python3-pyelftools doxygen zlib-devel
RUN python3 -m pip install meson==0.60.0

RUN yum install -y lbzip2 gcc gcc-c++ gmp-devel mpfr-devel libmpc-devel wget
RUN wget https://mirrors.aliyun.com/gnu/gcc/gcc-7.5.0/gcc-7.5.0.tar.gz && \
    tar -zxvf ./gcc-7.5.0.tar.gz
WORKDIR /gcc-7.5.0
RUN wget http://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
RUN wget http://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
RUN wget http://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
RUN wget http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.16.1.tar.bz2
RUN ./contrib/download_prerequisites
RUN mkdir ./build && cd ./build && \
    ../configure --prefix=/usr --enable-languages=c,c++ --disable-multilib && \
    make -j$(nproc) && make install
WORKDIR /
RUN rm -rf /gcc-7.5.0 && rm ./gcc-7.5.0.tar.gz

#RUN yum install -y centos-release-scl
#RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' \
#    -e "s|^# \?baseurl=http://mirror.centos.org/centos/7/sclo|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/sclo|g" \
#    -i /etc/yum.repos.d/CentOS-*.repo
#RUN yum install -y devtoolset-7
#RUN source /opt/rh/devtoolset-7/enable
#RUN echo "source /opt/rh/devtoolset-7/enable" >> /etc/profile

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

RUN wget https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.gz && tar -zxvf autoconf-2.71.tar.gz
WORKDIR /autoconf-2.71
RUN ./configure --prefix=/usr
RUN make && make install
WORKDIR /
RUN rm -f autoconf-2.71.tar.gz \
    && rm -rf /autoconf-2.71

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
ENV ImageOS=centos7

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

RUN yum install bison patchelf -y
RUN wget http://ftp.gnu.org/pub/gnu/make/make-4.2.tar.gz && \
    tar -xzvf make-4.2.tar.gz && \
    cd make-4.2/ && \
    mkdir build && cd build && \
    ../configure --prefix=/usr/ && \
    make && \
    make install && \
    rm /usr/bin/make && \
    cp make /usr/bin/
RUN rm -f make-4.2.tar.gz \
    && rm -rf /make-4.2

RUN wget https://ftp.gnu.org/gnu/glibc/glibc-2.28.tar.gz && \
    tar -xzvf glibc-2.28.tar.gz && \
    cd glibc-2.28 && \
    mkdir build && cd build && \
    ../configure --prefix=/usr/glibc-2.28 --disable-profile --enable-add-ons --with-headers=/usr/include --with-binutils=/usr/bin && \
    make -j$(nproc) && \
    make install
RUN rm -rf /glibc-2.28 && rm -rf glibc-2.28.tar.gz

RUN yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
RUN yum -y install git ninja-build

RUN patchelf --set-interpreter /usr/glibc-2.28/lib/ld-linux-x86-64.so.2 --set-rpath '/usr/glibc-2.28/lib:/lib64:/usr/lib' \
    /runnertmp/externals/node20/bin/node

RUN yum install -y sshpass

RUN yum clean all

USER runner
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]
