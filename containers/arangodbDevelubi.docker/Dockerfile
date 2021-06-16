FROM registry.access.redhat.com/ubi8/ubi-minimal:8.4
MAINTAINER Frank Celler <info@arangodb.com>

RUN microdnf update -y && rm -rf /var/cache/yum

# Metadata (required)
ARG name
ARG vendor
ARG version
ARG release
ARG summary
ARG description
ARG maintainer

LABEL name="$name" \
      vendor="$vendor" \
      version="$version" \
      release="$release" \
      summary="$summary" \
      description="$description" \
      maintainer="$maintainer"

ADD ./LICENSE /licenses/LICENSE

ENV GLIBCXX_FORCE_NEW=1


RUN microdnf install gpg wget binutils && \
    curl -L -O http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/numactl-libs-2.0.12-11.el8.x86_64.rpm && \
    rpm -i numactl-libs-2.0.12-11.el8.x86_64.rpm && \
    rm numactl-libs-2.0.12-11.el8.x86_64.rpm && \
    curl -L -O http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/numactl-2.0.12-11.el8.x86_64.rpm && \
    rpm -i numactl-2.0.12-11.el8.x86_64.rpm && \
    rm numactl-2.0.12-11.el8.x86_64.rpm && \
    microdnf clean all

ADD install.tar.gz /
COPY setup.sh /setup.sh
RUN /setup.sh && rm /setup.sh

# The following is magic for unholy OpenShift security business.
# Containers in OpenShift by default run with a random UID but with GID 0,
# and we want that they can access the database and doc directories even
# without a volume mount:
RUN chgrp 0 /var/lib/arangodb3 /var/lib/arangodb3-apps && \
    chmod 775 /var/lib/arangodb3 /var/lib/arangodb3-apps

# retain the database directory and the Foxx Application directory
VOLUME ["/var/lib/arangodb3", "/var/lib/arangodb3-apps"]

COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 8529
CMD ["arangod"]
