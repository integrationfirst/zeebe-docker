FROM eclipse-temurin:17-jre-focal AS builder

# build arguments for user/group configurations
ARG USER=zeebe
ARG USER_ID=802
ARG USER_GROUP=zeebe
ARG USER_GROUP_ID=802
ARG USER_HOME=/home/${USER}

ARG PRODUCT_REPOSITORY_NAME=zeebe
ARG PRODUCT_NAME=camunda-cloud-zeebe
ARG PRODUCT_VERSION=1.1.4
ARG PRODUCT=${PRODUCT_NAME}-${PRODUCT_VERSION}
ARG PRODUCT_HOME=${USER_HOME}/${PRODUCT}
ARG PRODUCT_DIST_URL=https://github.com/camunda-cloud/${PRODUCT_REPOSITORY_NAME}/releases/download/${PRODUCT_VERSION}/${PRODUCT}.tar.gz

ARG TMP_DIR=/tmp/zeebe
ARG TINI_VERSION=v0.19.0

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl jq wget

RUN wget -O /tmp/${PRODUCT}.tar.gz "${PRODUCT_DIST_URL}"

RUN mkdir -p ${TMP_DIR} && \
    tar xfvz /tmp/${PRODUCT}.tar.gz --strip 1 -C ${TMP_DIR} && \
    # already create volume dir to later have correct rights
    mkdir ${TMP_DIR}/data

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini ${TMP_DIR}/bin/tini
COPY docker/utils/startup.sh ${TMP_DIR}/bin/startup.sh
RUN chmod +x -R ${TMP_DIR}/bin/
RUN chmod 0775 ${TMP_DIR} ${TMP_DIR}/data




# BUILD APPLICATION IMAGE

FROM eclipse-temurin:17-jre-focal

ENV ZB_HOME=/usr/local/zeebe \
    ZEEBE_BROKER_GATEWAY_NETWORK_HOST=0.0.0.0 \
    ZEEBE_STANDALONE_GATEWAY=false
ENV PATH "${ZB_HOME}/bin:${PATH}"

WORKDIR ${ZB_HOME}
EXPOSE 26500 26501 26502
VOLUME ${ZB_HOME}/data

RUN groupadd -g 1000 zeebe && \
    adduser -u 1000 zeebe --system --ingroup zeebe && \
    chmod g=u /etc/passwd && \
    chown 1000:0 ${ZB_HOME} && \
    chmod 0775 ${ZB_HOME}

COPY --from=builder --chown=1000:0 /tmp/zeebe/bin/startup.sh /usr/local/bin/startup.sh
COPY --from=builder --chown=1000:0 /tmp/zeebe ${ZB_HOME}

ENTRYPOINT ["tini", "--", "/usr/local/bin/startup.sh"]