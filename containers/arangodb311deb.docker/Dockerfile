FROM ubuntu:24.04
MAINTAINER Max Neunhoeffer <hackers@arangodb.com>

RUN apt-get update && apt-get install -y --no-install-recommends curl jq pwgen numactl elfutils sysstat ca-certificates vim lsof && apt-get autoremove -y && apt-get clean
RUN apt-get install --no-install-recommends -y nodejs && apt-get install --no-install-recommends -y npm && npm install -g foxx-cli && apt-get purge -y npm && apt-get autoremove -y && apt-get clean

ENV GLIBCXX_FORCE_NEW=1

ADD install.tar.gz /
COPY setup.sh /setup.sh
RUN /setup.sh && rm /setup.sh

# Adjust TZ by default since tzdata package isn't present (BTS-913)
RUN echo "UTC" > /etc/timezone

# The following is magic for unholy OpenShift security business.
# Containers in OpenShift by default run with a random UID but with GID 0,
# and we want that they can access the database and doc directories even
# without a volume mount:
RUN chgrp 0 /var/lib/arangodb3 /var/lib/arangodb3-apps && \
    chmod 775 /var/lib/arangodb3 /var/lib/arangodb3-apps

COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 8529
CMD [ "arangod" ]
