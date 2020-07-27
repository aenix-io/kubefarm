FROM ubuntu:20.04 as rootfs

# Install packages
ARG DEBIAN_FRONTEND=noninteractive
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
      iptraf \
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
ARG KUBE_VERSION=1.18
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

FROM ubuntu:20.04 as builder

# Common build-dependencies
RUN apt-get -y update \
 && apt-get -y install git build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \

# Build dnsmasq
ARG DNSMAQ_VERSION=2.81-12-g619000a
RUN git clone git://thekelleys.org.uk/dnsmasq.git \
 && cd dnsmasq/ \
 && git checkout ${DNSMAQ_VERSION} \
 && make

# Build darkhttpd
ARG DARKHTTPD_VERSION=r2
RUN git clone https://github.com/ryanmjacobs/darkhttpd \
 && cd darkhttpd/ \
 && git checkout ${DARKHTTPD_VERSION} \
 && make install

# Install booty
ARG BOOTY_VERSION=4cf987460c7769fe3ac3c2d617b417a0defdc797
RUN apt-get -y update \
 && apt-get -y install \
      cpio \
      squashfs-tools \
      kmod \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && git clone https://github.com/sp00f1ng/booty.git \
 && cd booty \
 && git checkout ${BOOTY_VERSION} \
 && make install

COPY --from=rootfs / /rootfs

RUN mkdir -p /initramfs \
 && KERNEL_VERSION="$(ls -1 /rootfs/lib/modules/ | tail -n1)" \
 && mkdir -p /initramfs/lib/modules/${KERNEL_VERSION}/kernel/fs/overlayfs \
 && cp /rootfs/lib/modules/${KERNEL_VERSION}/modules.* /initramfs/lib/modules/${KERNEL_VERSION}/ \
 && cp /rootfs/lib/modules/${KERNEL_VERSION}/kernel/fs/overlayfs/overlay.ko /initramfs/lib/modules/${KERNEL_VERSION}/kernel/fs/overlayfs/overlay.ko \
 && mkdir -p /initramfs/lib/modules-load.d \
 && echo overlay > /initramfs/lib/modules-load.d/overlay.conf \
 && depmod -a -v -b /initramfs "${KERNEL_VERSION}"

RUN /usr/bin/mkinitramfs /initramfs --overlay /rootfs --output /initrd --squashfs

#-------------------------------------------------------------------------------

FROM ubuntu:20.04

RUN apt-get -y update \
 && apt-get -y install \
      grub-pc-bin \
      grub-efi-amd64-bin \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /dnsmasq/src/dnsmasq /usr/sbin/dnsmasq
COPY --from=builder /usr/bin/darkhttpd /usr/bin/darkhttpd
COPY --from=builder /initrd /tftp/initrd
COPY --from=rootfs /boot/vmlinuz /tftp/vmlinuz
COPY grub.cfg /tftp/grub.cfg

RUN grub-mknetdir --net-directory="/tftp" --subdir="/"
