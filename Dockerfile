FROM registry.fedoraproject.org/fedora-minimal:latest
RUN microdnf install procps-ng perf numactl iproute kernel-tools rsync tar kubernetes-client pcm jq -y \
      && microdnf clean all -y
COPY gather /usr/local/bin/gather
COPY resources /resources
CMD ["/gather"]
