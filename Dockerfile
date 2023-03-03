FROM registry.fedoraproject.org/fedora-minimal:latest
COPY gather /usr/local/bin/gather
CMD ["/gather"]
