#ARG APP_ENV=prod
FROM eclipse-temurin:17-jre-focal AS builder
# Building builder image
#FROM alpine:latest as builder
#ARG DISTBALL

# build arguments for user/group configurations
ARG USER=zeebe
ARG USER_ID=802
ARG USER_GROUP=wso2
ARG USER_GROUP_ID=802
ARG USER_HOME=/home/${USER}

ARG PRODUCT_REPOSITORY_NAME=zeebe
ARG PRODUCT_NAME=camunda-cloud-zeebe
ARG PRODUCT_VERSION=1.3.4
ARG PRODUCT=${PRODUCT_NAME}-${PRODUCT_VERSION}
ARG PRODUCT_HOME=${USER_HOME}/${PRODUCT}
ARG PRODUCT_DIST_URL=https://github.com/camunda-cloud/${PRODUCT_REPOSITORY_NAME}/releases/download/${PRODUCT_VERSION}/${PRODUCT}.tar.gz
# Sample: https://github.com/camunda-cloud/zeebe/releases/download/1.3.4/camunda-cloud-zeebe-1.3.4.tar.gz

ARG TMP_ARCHIVE=/tmp/zeebe.tar.gz
ARG TMP_DIR=/tmp/zeebe
ARG TINI_VERSION=v0.19.0

#COPY ${DISTBALL} ${TMP_ARCHIVE}

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

# Building prod image
#FROM eclipse-temurin:17-jre-focal as prod

# Building dev image
#FROM eclipse-temurin:17-jdk-focal as dev
#RUN echo "running DEV pre-install commands"
#RUN apt-get update
#RUN curl -sSL https://github.com/jvm-profiling-tools/async-profiler/releases/download/v1.7.1/async-profiler-1.7.1-linux-x64.tar.gz | tar xzv

# Building application image
#FROM ${APP_ENV} as app

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