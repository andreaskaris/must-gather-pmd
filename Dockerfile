FROM registry.fedoraproject.org/fedora-minimal:latest
COPY gather /gather
CMD ["/gather"]
