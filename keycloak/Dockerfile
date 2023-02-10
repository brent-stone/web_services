# https://www.keycloak.org/server/containers
#FROM quay.io/keycloak/keycloak:20.0.2 as builder
#
## Enable health and metrics support
#ENV KC_HEALTH_ENABLED=true
#ENV KC_METRICS_ENABLED=true
#
## Configure a database vendor
#ENV KC_DB=postgres
#
#WORKDIR /opt/keycloak
## for demonstration purposes only, please make sure to use proper certificates in production instead
#RUN keytool -genkeypair -storepass password -storetype PKCS12 -keyalg RSA -keysize 2048 -dname "CN=server" -alias server -ext "SAN:c=DNS:localhost,IP:127.0.0.1" -keystore conf/server.keystore
#RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:20.0.2 as production

# Copy password blacklist
CMD mkdir -p /opt/keycloak/data/password-blacklists/
COPY ./10_million_password_list_top_100000.txt /opt/keycloak/data/password-blacklists/10_million_password_list_top_100000.txt

# Copy and register TLS certs
COPY ./certs/webservices.crt /opt/keycloak/conf/webservices.crt
COPY ./certs/webservices.key /opt/keycloak/conf/webservices.key
ENV KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/webservices.crt
ENV KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/webservices.key


# Modify the redhat buffer sizes so KeyCloak is happy
# 16DEC22 NOTE: Tried a couple different approaches and nothing stuck. ignoring.
#USER root
# https://developer.jboss.org/thread/272212
# Allow a 25MB UDP receive buffer for JGroups
# RUN echo "26214400" > /proc/sys/net/core/rmem_max
# Allow a 1MB UDP send buffer for JGroups
# RUN echo "1048576" > /proc/sys/net/core/wmem_max
USER keycloak

# The published Keycloak containers have a directory /opt/keycloak/data/import.
# If you put one or more import files in that directory via a volume mount or other
# means and add the startup argument --import-realm, the Keycloak container will import
# that data on startup!
#CMD mkdir -p /opt/keycloak/data/import
#COPY ./realm_backup /opt/keycloak/data/import

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]