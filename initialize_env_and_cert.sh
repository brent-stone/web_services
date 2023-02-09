#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
YELLOW='\033[0;93m'
NO_COLOR='\033[0m'

echo "HTTPS_PORT is ${HTTPS_PORT}"

########## SELF-SIGNED CERT GENERATION TO ENABLE TLS ##########
# First, generate a self-signed certificate. These typically only work on localhost
# during development. Use Let's Encrypt or something similar when deploying as a public
# facing production service.
# https://letsencrypt.org/docs/certificates-for-localhost/#making-and-trusting-your-own-certificates
SELF_CERT_NAME_BASE="webservices"
SELF_CERT_NAME="${SELF_CERT_NAME_BASE}.crt"
SELF_KEY_NAME="${SELF_CERT_NAME_BASE}.key"
SELF_CERT="./certs/${SELF_CERT_NAME}"
SELF_KEY="./certs/${SELF_KEY_NAME}"
# Check if certificate and key exist
if [[ -f ${SELF_CERT} || -f ${SELF_KEY} ]]; then
  echo -e "${YELLOW}$SELF_CERT or $SELF_KEY already exists${NO_COLOR}. To reset, remove both then re-run \
this script."
# If not, generate them
else
  # Create the self signed public cert and private key for the 'localhost' & 'keycloak' DNS names
  # localhost is used by services running on the container host outside the containers
  # keycloak is used internally to the docker services to call out to the keycloak service
#  openssl req -x509 -out ${SELF_CERT} -keyout ${SELF_KEY} \
#  -newkey rsa:4096 -nodes -sha256 \
#  -subj '/CN=localhost' -extensions EXT -config <(
#  printf "[dn]\nCN=localhost\n[req]\ndistinguished_name=dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
  openssl req -x509 -out ${SELF_CERT} -keyout ${SELF_KEY} -newkey rsa:4096 -nodes \
   -sha256 -config openssl.cnf

  # Copy public certificate and private key to the keycloak certs folder
  # NOTE: cp overwrites by default
  mkdir -p ./keycloak/certs
  cp ${SELF_CERT} ./keycloak/certs/${SELF_CERT_NAME}
  cp ${SELF_KEY} ./keycloak/certs/${SELF_KEY_NAME}

  # Copy public certificate to the API server certs folder
  mkdir -p ./backend/webservices/core/certs
  cp ${SELF_CERT} ./backend/webservices/core/certs/${SELF_CERT_NAME}
fi

# NOTE: You can later verify all is good with the public certificate by running
# openssl x509 -in <cert_file_path>.crt -noout -text

########## Random String Generation Functions ##########
# If environment variables are set for the respective variables, passwords and secrets
# will be re-used so that Postgres and other stateful containers don't need to be wiped
# because new passwords/secrets were generated
RANDOM_STRING="random_string_was_not_generated!!"
STRING_LENGTH=32

RANDOM_STRING_CORPUS='A-Za-z0-9!%&*+,-./:;<>@^_|~'
RANDOM_USER_CORPUS='A-Za-z@_#'
# Function to generate a STRING_LENGTH string of characters
rando_string() {
    RANDOM_STRING=$(env LC_ALL=C tr -dc "$RANDOM_STRING_CORPUS" </dev/urandom |
    head -c $STRING_LENGTH)
}

# Function to generate viable postgres username which must start with a letter, @, _, or
# # For simplicity, simply make the whole username STRING_LENGTH valid starting
# characters
rando_user() {
  RANDOM_STRING=$(env LC_ALL=C tr -dc "$RANDOM_USER_CORPUS" </dev/urandom |
  head -c $STRING_LENGTH)
}

######### Variable Declarations #############

# Output filenames
ENV_FILE="./.env"
TEST_ENV_FILE="./backend/.test.env"

# Used to modify pytest and logging behavior within the FastAPI and SQLAlchemy services
DEBUG="false"

# Top Level Domain (TLS) the services are hosted under
# E.G. 'localhost' or 'google.com'
DOMAIN=${DOMAIN:="localhost"}

# Used to modify Uvicorn and FastAPI layer logging
LOG_LEVEL="warning"
LOG_LEVEL_DEBUG="debug"

# Used by React frontend
HTTP_PORT=${HTTPS_PORT:="80"}
HTTPS_PORT=${HTTPS_PORT:="443"}

# Used by FastAPI and Pydantic BaseSettings ingest
API_PORT="57073"
PROJECT_NAME="WebServices"
PROJECT_VERSION="0.2.12"
HASH_ALGORITHM="HS256"
ACCESS_TOKEN_EXPIRE_MINUTES="10080"  # 60 minutes * 24 hours * 7 days
DEFAULT_USERNAME="ccd"
rando_string
DEFAULT_USER_PASS=${DEFAULT_USER_PASS:-$RANDOM_STRING}
DEFAULT_EMAIL="contact@webservices.com"

POSTGRES_USER="webservices"
POSTGRES_DB="webservices"
# These following settings are used by FastAPI API layer under core > config.py
######## DEVELOPER INFO ########
# Ensure \backend\.test.env used by pytest uses POSTGRES_SERVER value of localhost or IP
# of running postgres container instead of using a docker service alias like db.
POSTGRES_SERVER="db"
POSTGRES_PORT="57074"

# .test.env specific settings for pytest and local development
TEST_DEBUG="true"
TEST_POSTFIX="_test"
TEST_POSTGRES_SERVER="db.${DOMAIN}"
ADMINER_PORT="57075"

# Redis Settings
REDIS_PORT="57076"
REDIS_HOST="redis"
REDIS_DB=${POSTGRES_SERVER}
TEST_REDIS_HOST="redis.${DOMAIN}"

# Flower (Celery) Redis Dashboard Settings
FLOWER_PORT="57077"

# Generate viable random values for the user/pass & encryption environment variables
rando_user
RANDOM_USER=${RANDOM_USER:-$RANDOM_STRING}
rando_string
RANDOM_SECRET_STR=${RANDOM_SECRET_STR:-$RANDOM_STRING}
rando_string
RANDOM_POSTGRES_PW=${RANDOM_POSTGRES_PW:-$RANDOM_STRING}
rando_string
RANDOM_REDIS_PW=${RANDOM_REDIS_PW:-$RANDOM_STRING}

# KeyCloak Settings
# Documentation of available environment variables available at
# https://www.keycloak.org/server/all-config
# With the exception of KEYCLOAK_ADMIN and KEYCLOAK_ADMIN_PASSWORD, all variables
# like KC_* are 'official' configs. All other configs are bespoke to this
# orchestration and unrelated to the official keycloak configuration settings.
# KEYCLOAK_HOSTNAME is the hostname OTHER services use to refer to the keycloak service
KEYCLOAK_HOSTNAME_PROD="keycloak"
KEYCLOAK_HOSTNAME_DEV="localhost"
# KC_HOSTNAME sets keycloak's internal understanding of what it thinks its hostname is
# KEYCLOAK_HOSTNAME_DEV="keycloak.${DOMAIN}"
KEYCLOAK_HOSTNAME_DEV="keycloak.localhost"
KC_HOSTNAME="keycloak.${DOMAIN}"
#KC_HOSTNAME="localhost"
KC_HTTP_PORT=57081
KC_HTTPS_PORT=${KC_HTTPS_PORT:=57444}
KC_HTTPS_PORT_DEV=${KC_HTTPS_PORT_DEV:-$HTTPS_PORT}

KC_DB="postgres"
KC_DB_USERNAME="webservices_keycloak"
KC_DB_PASSWORD=${KC_DB_PASSWORD:-$RANDOM_POSTGRES_PW}
KC_DB_URL_HOST="db"
KC_DB_URL_PORT=5432
KC_DB_URL_DATABASE="webservices_keycloak"
KC_DB_SCHEMA="public"
KEYCLOAK_ADMIN="webservices_keycloak_admin"
rando_string
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-$RANDOM_STRING}
KC_TRANSACTION_XA_ENABLED="true"
KC_HEALTH_ENABLED="true"
KC_METRICS_ENABLED="true"
KC_FEATURES="account2,admin2,ciba,par,authorization,recovery-codes,client-secret-rotation"
KC_HTTPS_CERTIFICATE_FILE="/opt/keycloak/conf/${SELF_CERT_NAME}"
KC_HTTPS_CERTIFICATE_KEY_FILE="/opt/keycloak/conf/${SELF_KEY_NAME}"
rando_string
KC_HTTPS_TRUST_STORE_PASSWORD=${KC_HTTPS_TRUST_STORE_PASSWORD:-$RANDOM_STRING}
# NOTE: This hardcoded secret key matches what is in the Keycloak realm backup file to
# enable more rapid development. Be sure to change using Keycloak admin UI in prod
rando_string
KEYCLOAK_CLIENT_SECRET_KEY=${KEYCLOAK_CLIENT_SECRET_KEY:-$RANDOM_STRING}
KEYCLOAK_LOGIN_WAIT_SEC=3
KEYCLOAK_LOGIN_RETRY_COUNT=10
KC_PROXY="passthrough"

BACKEND_CORS_ORIGINS="[\
\"https://${DOMAIN}:443\",\
\"https://webservices.${DOMAIN}\",\
\"https://api.${DOMAIN}\",\
\"https://keylcoak.${DOMAIN}\",\
\"http://webservices-proxy\",\
\"https://webservices-proxy\",\
\"http://webservices-web\",\
\"https://webservices-web\",\
\"http://webservices-web-dev\",\
\"https://webservices-web-dev\"\
]"


BACKEND_CORS_ORIGINS_TRAEFIK="\
https://${DOMAIN}:443,\
https://webservices.${DOMAIN},\
https://api.${DOMAIN},\
https://keycloak.${DOMAIN},\
http://webservices-proxy,\
https://webservices-proxy,\
http://webservices-web,\
https://webservices-web,\
http://webservices-web-dev,\
https://webservices-web-dev\
"

# Traefik Settings
TRAEFIK_TAG="webservices"
TRAEFIK_PUBLIC_NETWORK="traefik-public"
TRAEFIK_PUBLIC_TAG="traefik-public"

# Docker Swarm Settings
STACK_NAME="webservices-com"

######### Output to ENV_FILE and TEST_ENV_FILE  #############

# Check if 'prod' .env file already exists
if [ -f $ENV_FILE ]; then
  echo -e "${YELLOW}$ENV_FILE file already exists${NO_COLOR}. To reset, remove it then re-run this script."
# If not, initialize it with new key:value pairs
else
  # Create the .env file
  touch $ENV_FILE

  # Write to the file
  {
    echo "# General Settings";
    echo "DEBUG=${DEBUG}";

    echo "# Uvicorn gateway and API logging settings";
    echo "# Uvicorn log level values: 'critical', 'error', 'warning', 'info', 'debug'";
    echo "LOG_LEVEL=${LOG_LEVEL}";

    echo "# React Frontend Settings";
    echo "HTTP_PORT=${HTTP_PORT:-$HTTP_PORT}";
    echo "HTTPS_PORT=${HTTPS_PORT:-$HTTPS_PORT}";

    echo "# FastAPI Settings";
    echo "API_PORT=${API_PORT:-$API_PORT}";
    echo "PROJECT_NAME=${PROJECT_NAME}";
    echo "PROJECT_VERSION=${PROJECT_VERSION}";
    echo "DEFAULT_USERNAME=${DEFAULT_USERNAME}";
    echo "DEFAULT_USER_PASS=${DEFAULT_USER_PASS}";
    echo "DEFAULT_EMAIL=${DEFAULT_EMAIL}";
    echo "HASH_ALGORITHM=${HASH_ALGORITHM}";
    echo "ACCESS_TOKEN_EXPIRE_MINUTES=${ACCESS_TOKEN_EXPIRE_MINUTES}";
    echo "BACKEND_CORS_ORIGINS=${BACKEND_CORS_ORIGINS}";
    echo "BACKEND_CORS_ORIGINS_TRAEFIK=${BACKEND_CORS_ORIGINS_TRAEFIK}";
    echo "SECRET_KEY=${SECRET_KEY:-$RANDOM_SECRET_STR}";
    echo "# These variables control the keycloak connection timeout and retry behavior of the /backend services";
    echo "KEYCLOAK_LOGIN_WAIT_SEC=${KEYCLOAK_LOGIN_WAIT_SEC:-$KEYCLOAK_LOGIN_WAIT_SEC}";
    echo "KEYCLOAK_LOGIN_RETRY_COUNT=${KEYCLOAK_LOGIN_RETRY_COUNT:-$KEYCLOAK_LOGIN_RETRY_COUNT}";
    echo "# SQLAlchemy 2.0 migration specific warning flag";
    echo "# remove once SQLAlchemy is officially updated to 2.0";
    echo "SQLALCHEMY_WARN_20=1";

    echo "# Postgres Settings (also used by FastAPI)";
    echo "POSTGRES_USER=${POSTGRES_USER:-$RANDOM_USER}";
    echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$RANDOM_POSTGRES_PW}";
    echo "POSTGRES_DB=${POSTGRES_DB:-$POSTGRES_DB}";
    echo "POSTGRES_SERVER=${POSTGRES_SERVER:-$POSTGRES_SERVER}";
    echo "POSTGRES_PORT=${POSTGRES_PORT:-$POSTGRES_PORT}";

    echo "# Postgres Adminer dashboard settings (dev only)";
    echo "ADMINER_PORT=${ADMINER_PORT:-$ADMINER_PORT}";

    echo "# Redis (Celery) Settings";
    echo "REDIS_HOST=${REDIS_HOST:-$REDIS_HOST}";
    echo "REDIS_PASSWORD=${REDIS_PASSWORD:-$RANDOM_REDIS_PW}";
    echo "REDIS_PORT=${REDIS_PORT:-$REDIS_PORT}";
    echo "REDIS_DB=${REDIS_DB:-$REDIS_DB}";
    echo "CELERY_BROKER_URL=redis://${REDIS_HOST:-$REDIS_HOST}/0";
    echo "CELERY_RESULT_BACKEND=redis://${REDIS_HOST:-$REDIS_HOST}/0";

    echo "# Redis (Celery) Flower dashboard settings (dev only)";
    echo "FLOWER_PORT=${FLOWER_PORT:-$FLOWER_PORT}";

    echo "# Official Keycloak Image Settings";
    echo "KC_HOSTNAME=${KC_HOSTNAME:-$KC_HOSTNAME}";
    echo "KC_HTTP_PORT=${KC_HTTP_PORT:-$KC_HTTP_PORT}";
    echo "KC_HTTPS_PORT=${KC_HTTPS_PORT:-$KC_HTTPS_PORT}";
    echo "KC_DB=${KC_DB:-$KC_DB}";
    echo "KC_DB_USERNAME=${KC_DB_USERNAME:-$KC_DB_USERNAME}";
    echo "KC_DB_PASSWORD=${KC_DB_PASSWORD:-$KC_DB_PASSWORD}";
    echo "KC_DB_URL_HOST=${KC_DB_URL_HOST:-$KC_DB_URL_HOST}";
    echo "KC_DB_URL_PORT=${KC_DB_URL_PORT:-$KC_DB_URL_PORT}";
    echo "KC_DB_URL_DATABASE=${KC_DB_URL_DATABASE:-$KC_DB_URL_DATABASE}";
    echo "KC_DB_SCHEMA=${KC_DB_SCHEMA:-$KC_DB_SCHEMA}";
    echo "KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-$KEYCLOAK_ADMIN}";
    echo "KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-$KEYCLOAK_ADMIN_PASSWORD}";
    echo "KC_TRANSACTION_XA_ENABLED=${KC_TRANSACTION_XA_ENABLED:-$KC_TRANSACTION_XA_ENABLED}";
    echo "KC_HEALTH_ENABLED=${KC_HEALTH_ENABLED:-$KC_HEALTH_ENABLED}";
    echo "KC_METRICS_ENABLED=${KC_METRICS_ENABLED:-$KC_METRICS_ENABLED}";
    echo "# https://www.keycloak.org/server/features#_supported_features";
    echo "KC_FEATURES=${KC_FEATURES:-$KC_FEATURES}";
    echo "KC_HTTPS_TRUST_STORE_PASSWORD=${KC_HTTPS_TRUST_STORE_PASSWORD:-$KC_HTTPS_TRUST_STORE_PASSWORD}";
    echo "# Reverse Proxy configuration";
    echo "KC_PROXY=${KC_PROXY:-$KC_PROXY}";

    echo "# Bespoke Keycloak configuration settings";
    echo "KEYCLOAK_HOSTNAME=${KEYCLOAK_HOSTNAME_PROD:-$KEYCLOAK_HOSTNAME_PROD}";
    echo "KC_HTTPS_CERTIFICATE_FILE=${KC_HTTPS_CERTIFICATE_FILE:-$KC_HTTPS_CERTIFICATE_FILE}";
    echo "KC_HTTPS_CERTIFICATE_KEY_FILE=${KC_HTTPS_CERTIFICATE_KEY_FILE:-$KC_HTTPS_CERTIFICATE_KEY_FILE}";
    echo "# These variables are referenced in the /keycloak/realm_backup/realm-export.json";
    echo "KEYCLOAK_CLIENT_SECRET_KEY=${KEYCLOAK_CLIENT_SECRET_KEY:-$KEYCLOAK_CLIENT_SECRET_KEY}";
    echo "GOOGLE_CLIENT_SECRET=<REPLACE-ME>";
    echo "GITHUB_CLIENT_SECRET=<REPLACE-ME>";

    echo "# Traefik Settings and Labels";
    echo "DOMAIN=${DOMAIN:-$DOMAIN}";
    echo "TRAEFIK_PUBLIC_NETWORK=${TRAEFIK_PUBLIC_NETWORK:-$TRAEFIK_PUBLIC_NETWORK}";
    echo "TRAEFIK_TAG=${TRAEFIK_TAG:-$TRAEFIK_TAG}";
    echo "TRAEFIK_PUBLIC_TAG=${TRAEFIK_PUBLIC_TAG:-$TRAEFIK_PUBLIC_TAG}";

    echo "# Docker Swarm Settings";
    echo "STACK_NAME=${STACK_NAME:-$STACK_NAME}";
  } >> $ENV_FILE
fi

# Check if 'test' .test.env file already exists
if [ -f $TEST_ENV_FILE ]; then
  echo -e "${YELLOW}$TEST_ENV_FILE file already exists${NO_COLOR}. To reset, remove it then re-run this \
script."
# If not, initialize it with new key:value pairs
else
  # Create the .env file
  touch $TEST_ENV_FILE

  # Write to the file
  {
    echo "# General Settings";
    echo "DEBUG=${TEST_DEBUG}";

    echo "# Uvicorn gateway and API logging settings";
    echo "# Uvicorn log level values: 'critical', 'error', 'warning', 'info', 'debug'";
    echo "LOG_LEVEL=${LOG_LEVEL_DEBUG}";

    echo "# React Frontend Settings";
    echo "HTTP_PORT=${HTTP_PORT:-$HTTP_PORT}";
    echo "HTTPS_PORT=${HTTPS_PORT:-$HTTPS_PORT}";

    echo "# FastAPI Settings";
    echo "API_PORT=${API_PORT:-$API_PORT}";
    echo "PROJECT_NAME=${PROJECT_NAME}";
    echo "PROJECT_VERSION=${PROJECT_VERSION}";
    echo "DEFAULT_USERNAME=${DEFAULT_USERNAME}";
    echo "DEFAULT_USER_PASS=${DEFAULT_USER_PASS}";
    echo "DEFAULT_EMAIL=${DEFAULT_EMAIL}";
    echo "HASH_ALGORITHM=${HASH_ALGORITHM}";
    echo "ACCESS_TOKEN_EXPIRE_MINUTES=${ACCESS_TOKEN_EXPIRE_MINUTES}";
    echo "BACKEND_CORS_ORIGINS=${BACKEND_CORS_ORIGINS}";
    echo "BACKEND_CORS_ORIGINS_TRAEFIK=${BACKEND_CORS_ORIGINS_TRAEFIK}";
    echo "SECRET_KEY=${SECRET_KEY:-$RANDOM_SECRET_STR}";
    echo "# These variables control the keycloak connection timeout and retry behavior of the /backend services";
    echo "KEYCLOAK_LOGIN_WAIT_SEC=${KEYCLOAK_LOGIN_WAIT_SEC:-$KEYCLOAK_LOGIN_WAIT_SEC}";
    echo "KEYCLOAK_LOGIN_RETRY_COUNT=${KEYCLOAK_LOGIN_RETRY_COUNT:-$KEYCLOAK_LOGIN_RETRY_COUNT}";
    echo "# SQLAlchemy 2.0 migration specific warning flag";
    echo "# remove once SQLAlchemy is officially updated to 2.0";
    echo "SQLALCHEMY_WARN_20=1";

    echo "# Postgres Settings (also used by FastAPI)";
    echo "POSTGRES_USER=${POSTGRES_USER:-$RANDOM_USER}";
    echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$RANDOM_POSTGRES_PW}";
    echo "POSTGRES_DB=${POSTGRES_DB:-$POSTGRES_DB}${TEST_POSTFIX}";
    echo "POSTGRES_SERVER=${TEST_POSTGRES_SERVER}";
    echo "POSTGRES_PORT=${POSTGRES_PORT:-$POSTGRES_PORT}";

    echo "# Postgres Adminer dashboard settings (dev only)";
    echo "ADMINER_PORT=${ADMINER_PORT:-$ADMINER_PORT}";

    echo "# Redis (Celery) Settings";
    echo "REDIS_HOST=${REDIS_HOST:-$REDIS_HOST}";
    echo "REDIS_PASSWORD=${REDIS_PASSWORD:-$RANDOM_REDIS_PW}";
    echo "REDIS_PORT=${REDIS_PORT:-$REDIS_PORT}";
    echo "REDIS_DB=${REDIS_DB:-$REDIS_DB}";
    echo "CELERY_BROKER_URL=redis://${TEST_REDIS_HOST:-$TEST_REDIS_HOST}:${REDIS_PORT:-$REDIS_PORT}/0";
    echo "CELERY_RESULT_BACKEND=redis://${TEST_REDIS_HOST:-$TEST_REDIS_HOST}:${REDIS_PORT:-$REDIS_PORT}/0";

    echo "# Redis (Celery) Flower dashboard settings (dev only)";
    echo "FLOWER_PORT=${FLOWER_PORT:-$FLOWER_PORT}";

    echo "# Official Keycloak Image Settings";
    echo "KC_HTTP_PORT=${KC_HTTP_PORT:-$KC_HTTP_PORT}";
    echo "KC_HTTPS_PORT=${KC_HTTPS_PORT_DEV:-$KC_HTTPS_PORT_DEV}";
    echo "KC_DB=${KC_DB:-$KC_DB}";
    echo "KC_DB_USERNAME=${KC_DB_USERNAME:-$KC_DB_USERNAME}";
    echo "KC_DB_PASSWORD=${KC_DB_PASSWORD:-$KC_DB_PASSWORD}";
    echo "KC_DB_URL_HOST=${KC_DB_URL_HOST:-$KC_DB_URL_HOST}";
    echo "KC_DB_URL_PORT=${KC_DB_URL_PORT:-$KC_DB_URL_PORT}";
    echo "KC_DB_URL_DATABASE=${KC_DB_URL_DATABASE:-$KC_DB_URL_DATABASE}";
    echo "KC_DB_SCHEMA=${KC_DB_SCHEMA:-$KC_DB_SCHEMA}";
    echo "KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-$KEYCLOAK_ADMIN}";
    echo "KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-$KEYCLOAK_ADMIN_PASSWORD}";
    echo "KC_TRANSACTION_XA_ENABLED=${KC_TRANSACTION_XA_ENABLED:-$KC_TRANSACTION_XA_ENABLED}";
    echo "KC_HEALTH_ENABLED=${KC_HEALTH_ENABLED:-$KC_HEALTH_ENABLED}";
    echo "KC_METRICS_ENABLED=${KC_METRICS_ENABLED:-$KC_METRICS_ENABLED}";
    echo "# https://www.keycloak.org/server/features#_supported_features";
    echo "KC_FEATURES=${KC_FEATURES:-$KC_FEATURES}";
    echo "KC_HTTPS_TRUST_STORE_PASSWORD=${KC_HTTPS_TRUST_STORE_PASSWORD:-$KC_HTTPS_TRUST_STORE_PASSWORD}";
    echo "# Reverse Proxy configuration";
    echo "KC_PROXY=${KC_PROXY:-$KC_PROXY}";

    echo "# Bespoke Keycloak configuration settings";
    echo "KEYCLOAK_HOSTNAME=${KEYCLOAK_HOSTNAME_DEV:-$KEYCLOAK_HOSTNAME_DEV}";
    echo "KC_HOSTNAME=${KC_HOSTNAME:-$KC_HOSTNAME}";
    echo "KC_HTTPS_CERTIFICATE_FILE=${KC_HTTPS_CERTIFICATE_FILE:-$KC_HTTPS_CERTIFICATE_FILE}";
    echo "KC_HTTPS_CERTIFICATE_KEY_FILE=${KC_HTTPS_CERTIFICATE_KEY_FILE:-$KC_HTTPS_CERTIFICATE_KEY_FILE}";
    echo "# These variables are referenced in the /keycloak/realm_backup/realm-export.json";
    echo "KEYCLOAK_CLIENT_SECRET_KEY=${KEYCLOAK_CLIENT_SECRET_KEY:-$KEYCLOAK_CLIENT_SECRET_KEY}";
    echo "GOOGLE_CLIENT_SECRET=<REPLACE-ME>";
    echo "GITHUB_CLIENT_SECRET=<REPLACE-ME>";

    echo "# Traefik Settings and Labels";
    echo "DOMAIN=${DOMAIN:-$DOMAIN}";
    echo "TRAEFIK_PUBLIC_NETWORK=${TRAEFIK_PUBLIC_NETWORK:-$TRAEFIK_PUBLIC_NETWORK}";
    echo "TRAEFIK_TAG=${TRAEFIK_TAG:-$TRAEFIK_TAG}";
    echo "TRAEFIK_PUBLIC_TAG=${TRAEFIK_PUBLIC_TAG:-$TRAEFIK_PUBLIC_TAG}";

    echo "# Docker Swarm Settings";
    echo "STACK_NAME=${STACK_NAME:-$STACK_NAME}";
  } >> $TEST_ENV_FILE
fi
