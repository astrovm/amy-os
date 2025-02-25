FROM quay.io/fedora/fedora-bootc:41

COPY system_files /
COPY build_files /tmp

RUN mkdir -p /var/opt && \
  /tmp/build.sh && \
  /tmp/fix-opt.sh && \
  /tmp/build-initramfs.sh && \
  /tmp/cleanup.sh && \
  ostree container commit && \
  bootc container lint
