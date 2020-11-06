#-------------------------------------------------------------------------------
# Base part used for ltsp-server and ltsp-client
#-------------------------------------------------------------------------------

FROM ubuntu:20.04 as ltsp

ENV VERSION=v0.7.1
ENV DEBIAN_FRONTEND=noninteractive

# Install updates and LTSP package
RUN apt-get -y update \
 && apt-get -y upgrade \
 && apt-get -y install \
      curl \
 && apt-get clean

RUN printf '%s\n' \
      'deb http://ppa.launchpad.net/ltsp/ppa/ubuntu focal main' \
      'deb http://ppa.launchpad.net/ltsp/proposed/ubuntu focal main' \
      > /etc/apt/sources.list.d/ltsp.list \
 && curl -L https://ltsp.org/misc/ltsp_ubuntu_ppa.gpg \
      -o /etc/apt/trusted.gpg.d/ltsp_ubuntu_ppa.gpg

RUN apt-get -y update \
 && apt-get -y install \
      ltsp-cloud \
 && apt-get clean

#-------------------------------------------------------------------------------
# Installing Kernel and basic software
#-------------------------------------------------------------------------------

FROM ltsp as rootfs-pre

# Install packages
RUN echo 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' \
      >> /etc/apt/apt.conf.d/01norecommend \
 && mkdir -p /var/lib/resolvconf \
 && touch /var/lib/resolvconf/linkified \
 && apt-get update \
 && apt-get -y install \
      adduser \
      apparmor-utils \
      apt-transport-https \
      arping \
      bash-completion \
      bridge-utils \
      ca-certificates \
      curl \
      dbus-user-session \
      gnupg \
      gpg-agent \
      htop \
      ifenslave \
      initramfs-tools \
      ipset \
      ipvsadm \
      jnettop \
      jq \
      linux-image-generic \
      lm-sensors \
      lvm2 \
      openssh-server \
      nano \
      net-tools \
      nfs-common \
      pciutils \
      resolvconf \
      rsync \
      screen \
      squashfs-tools \
      ssh \
      sysstat \
      systemd \
      sudo \
      tcpdump \
      telnet \
      thin-provisioning-tools \
      ubuntu-minimal \
      vim \
      vlan \
      wget \
      zfsutils-linux \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Disable systemd-resolved
RUN systemctl disable systemd-resolved.service \
 && systemctl mask systemd-resolved.service

# Install docker
ARG DOCKER_VERSION=19.03
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
 && echo "deb https://download.docker.com/linux/ubuntu focal stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && DOCKER_VERSION=$(apt-cache madison docker-ce | awk '{print $3}' | grep -m1 "$DOCKER_VERSION") \
 && apt-get -y install docker-ce="$DOCKER_VERSION" \
 && apt-mark hold docker-ce

# Install kubeadm, kubelet and kubectl
# https://kubernetes.io/docs/setup/independent/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
ARG KUBE_VERSION=1.19
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
 && echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" \
      > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update \
 && KUBE_VERSION=$(apt-cache madison kubelet | awk '{print $3}' | grep -m1 "$KUBE_VERSION") \
 && apt-get -y install kubelet=$KUBE_VERSION kubeadm=$KUBE_VERSION kubectl=$KUBE_VERSION cri-tools \
 && apt-mark hold kubelet kubeadm kubectl

# Disable automatic updates
RUN rm -f /etc/apt/apt.conf.d/20auto-upgrades

# Disable apparmor profiles
RUN find /etc/apparmor.d \
      -maxdepth 1 \
      -type f \
      -name "sbin.*" \
      -o -name "usr.*" \
      -exec ln -sf "{}" /etc/apparmor.d/disable/ \;

# Setup locales
RUN printf '%s\n' \
      'LANG=en_US.UTF-8' \
      'LC_TIME=en_DK.UTF-8' \
      'LC_CTYPE=en_US.UTF-8' \
      > /etc/locale.conf \
 && locale-gen en_US.UTF-8 en_DK.UTF-8

#-------------------------------------------------------------------------------
# Build kernel modules
#-------------------------------------------------------------------------------

FROM rootfs-pre as modules

# Install kernel-headers and dkms
RUN apt-get update \
 && KERNEL_VERSION="$(ls -1 /lib/modules/ | tail -n1)" \
 && apt-get -y install "linux-headers-${KERNEL_VERSION}" dkms \
 && apt-get clean

# Install DRBD modules
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC1B5A793C04BB3905AD837734893610CEAA9512 \
 && echo "deb http://ppa.launchpad.net/linbit/linbit-drbd9-stack/ubuntu focal main" \
      > /etc/apt/sources.list.d/linbit.list \
 && apt-get update \
 && apt-get -y install drbd-dkms

#-------------------------------------------------------------------------------
# Build rootfs image
#-------------------------------------------------------------------------------

FROM rootfs-pre as rootfs

# Copy kernel modules
COPY --from=modules /lib/modules/ /lib/modules/

# Generate initramfs with new modules
RUN update-initramfs -u

# Generate motd
COPY motd /etc/motd
RUN sed -i "s/\${VERSION}/${VERSION}/" /etc/motd

# Generate image
ENV OMIT_FUNCTIONS="remove_users"
RUN ltsp image -I /

#-------------------------------------------------------------------------------
# Build dnsmasq with tftp single port support
#-------------------------------------------------------------------------------

FROM ltsp as builder

# Common build-dependencies
RUN apt-get -y update \
 && apt-get -y install \
      git \
      build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \

# Build dnsmasq
ARG DNSMAQ_VERSION=2.81-12-g619000a
RUN git clone git://thekelleys.org.uk/dnsmasq.git \
 && cd dnsmasq/ \
 && git checkout ${DNSMAQ_VERSION} \
 && make

#-------------------------------------------------------------------------------
# LTSP-Server
#-------------------------------------------------------------------------------

FROM ltsp

RUN apt-get -y update \
 && apt-get -y install \
      grub-pc-bin \
      grub-efi-amd64-bin \
      inotify-tools \
      nginx \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Generate nginx config
RUN ltsp http -I

COPY --from=builder /dnsmasq/src/dnsmasq /usr/sbin/dnsmasq
COPY --from=rootfs /srv/ltsp/images /srv/ltsp/images
COPY --from=rootfs /srv/tftp/ltsp /srv/tftp/ltsp
