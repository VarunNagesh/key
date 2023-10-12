ARG KEYCLOAK_VERSION=11.0.3

# Using Red Hat base image
FROM registry.access.redhat.com/ubi9 AS ubi-micro-build
RUN mkdir -p /mnt/rootfs
RUN dnf install --installroot /mnt/rootfs git --releasever 9 --setopt install_weak_deps=false --nodocs -y; dnf --installroot /mnt/rootfs clean all
RUN dnf install --installroot /mnt/rootfs findutils --releasever 9 --setopt install_weak_deps=false --nodocs -y; dnf --installroot /mnt/rootfs clean all

# Building Keycloak
FROM registry.access.redhat.com/ubi9 AS keycloak-builder
WORKDIR /tmp

# Copying sunkingpay-keycloak repo into the container
COPY ./ /tmp/keycloak

WORKDIR /tmp/keycloak

# Install Maven
RUN dnf install maven --releasever 9 --setopt install_weak_deps=false --nodocs -y; dnf clean all

RUN mvn clean install -DskipTests

# Building keyclaok-metrics-spi extension on top of Keycloak custom image
FROM keycloak-builder as metrics-spi-builder
WORKDIR /tmp
RUN git clone https://github.com/aerogear/keycloak-metrics-spi.git keycloak-spi

WORKDIR /tmp/keycloak-spi
RUN ./gradlew -PkeycloakVersion="${KEYCLOAK_VERSION}" jar

# Creating the final Keycloak image
FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

COPY --from=metrics-spi-builder /tmp/keycloak-spi/build/libs/keycloak-metrics-spi-*.jar /opt/jboss/keycloak/standalone/deployments/
RUN ls /opt/jboss/keycloak/standalone/deployments/
RUN touch /opt/jboss/keycloak/standalone/deployments/keycloak-metrics-spi.jar.dodeploy
