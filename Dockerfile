################################################################################
# This Dockerfile was generated from the template at distribution/src/docker/Dockerfile
#
# Beginning of multi stage Dockerfile
################################################################################

################################################################################
# Build stage 0 `builder`:
# Extract elasticsearch artifact
# Install required plugins
# Set gid=0 and make group perms==owner perms
################################################################################

FROM centos:7 AS builder

ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV JAVA_HOME /opt/jdk-11.0.1

ARG ES_VERSION

RUN mkdir -p /opt/jdk-11.0.1 && curl --retry 8 -s -L https://corretto.aws/downloads/latest/amazon-corretto-8-aarch64-linux-jdk.tar.gz | tar --strip-components=1 -C /opt/jdk-11.0.1 -zxf -

# Replace OpenJDK's built-in CA certificate keystore with the one from the OS
# vendor. The latter is superior in several ways.
# REF: https://github.com/elastic/elasticsearch-docker/issues/171
RUN mkdir -p /opt/jdk-11.0.1/lib/security && ln -sf /etc/pki/ca-trust/extracted/java/cacerts /opt/jdk-11.0.1/lib/security/cacerts

RUN yum install -y unzip which

RUN groupadd -g 1000 elasticsearch && \
    adduser -u 1000 -g 1000 -d /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

RUN cd /opt && curl --retry 8 -s -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_VERSION}.tar.gz && cd -

RUN tar zxf /opt/elasticsearch-${ES_VERSION}.tar.gz --strip-components=1
RUN mkdir -p config data logs
RUN chmod 0775 config data logs
COPY config/elasticsearch.yml config/log4j2.properties config/

################################################################################
# Build stage 1 (the actual elasticsearch image):
# Copy elasticsearch from stage 0
# Add entrypoint
################################################################################

FROM centos:7

ENV ELASTIC_CONTAINER true
ENV JAVA_HOME /opt/jdk-11.0.1

COPY --from=builder /opt/jdk-11.0.1 /opt/jdk-11.0.1

RUN yum update -y && \
    yum install -y nc unzip wget which && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN groupadd -g 1000 elasticsearch && \
    adduser -u 1000 -g 1000 -G 0 -d /usr/share/elasticsearch elasticsearch && \
    chmod 0775 /usr/share/elasticsearch && \
    chgrp 0 /usr/share/elasticsearch

WORKDIR /usr/share/elasticsearch
COPY --from=builder --chown=1000:1000 /usr/share/elasticsearch /usr/share/elasticsearch
ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV xpack.security.enabled false
ENV xpack.monitoring.enabled false
ENV xpack.ml.enabled false

COPY --chown=1000:0 bin/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Openshift overrides USER and uses ones with randomly uid>1024 and gid=0
# Allow ENTRYPOINT (and ES) to run even with a different user
RUN chgrp 0 /usr/local/bin/docker-entrypoint.sh && \
    chmod g=u /etc/passwd && \
    chmod 0775 /usr/local/bin/docker-entrypoint.sh

EXPOSE 9200 9300

LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.vendor="Elastic" \
  org.label-schema.name="elasticsearch" \
  org.label-schema.version="${ES_VERSION}" \
  org.label-schema.url="https://www.elastic.co/products/elasticsearch" \
  org.label-schema.vcs-url="https://github.com/elastic/elasticsearch" \
  license="Elastic License"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Dummy overridable parameter parsed by entrypoint
CMD ["eswrapper"]

################################################################################
# End of multi-stage Dockerfile
################################################################################
