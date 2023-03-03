FROM registry.fedoraproject.org/fedora-minimal:latest
RUN microdnf install procps-ng perf numactl iproute kernel-tools rsync tar kubernetes-client -y \
      && microdnf clean all -y
COPY gather /usr/local/bin/gather
COPY collect /usr/local/bin/collect
CMD ["/gather"]
