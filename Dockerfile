FROM registry.fedoraproject.org/fedora-minimal:latest
RUN microdnf install procps-ng perf numactl iproute kernel-tools -y && microdnf clean all -y
COPY gather /usr/local/bin/gather
CMD ["/gather"]
