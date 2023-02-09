FROM python:3.11-slim as requirements-stage

WORKDIR /tmp

RUN pip install --upgrade pip poetry

COPY ./pyproject.toml pyproject.toml
COPY ./poetry.lock poetry.lock

RUN poetry export --format requirements.txt --output requirements.txt --without-hashes
RUN poetry export --format requirements.txt --output requirements-dev.txt --without-hashes --with dev

FROM python:3.11-slim as development

LABEL maintainer="Brent S <contact@webservices.com>"

# Ensure curl is available for healthcheck via curl
# Also ensure git and other dev dependencies are available for in container development
# The Git repo and information will be mounted via docker-compose
# The additional packages are to support compiling google-re python wheel with the C++
# library
# "Always combine RUN apt-get update with apt-get install in the same RUN statement."
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
# NOTE: The Git repo and information will be mounted via docker-compose
# The additional packages are to support compiling google-re python wheel with the C++
# library
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    git \
    gcc \
    g++ \
    libre2-dev \
    libpq-dev
    # Add additional installations here with trailing `\` on each line \

# Cleanup the apt cache to reduce image size
RUN apt-get purge -y --auto-remove
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /webservices/backend

COPY ./start.sh start.sh
RUN chmod +x start.sh

COPY ./gunicorn_conf.py gunicorn_conf.py

COPY ./start-reload.sh start-reload.sh
RUN chmod +x start-reload.sh

COPY ./prestart.sh prestart.sh
RUN chmod +x prestart.sh

COPY --from=requirements-stage /tmp/requirements-dev.txt /webservices/backend/requirements.txt

# Caching with BuildKit: https://pythonspeed.com/articles/docker-cache-pip-downloads/
# In you dev environment, be sure BuildKit is active using an enivornment variable:
# export DOCKER_BUILDKIT=1
# This setting may be permenently enabled on Ubuntu by adding it to user profile config
# via `gedit ~/.profile` in terminal
RUN --mount=type=cache,target=/root/.cache \
  pip install --upgrade -r requirements.txt

# Add self-signed public certificate to trusted certificate autorites.
# This allows TLS communication between other services like Keycloak
# You can verify the certificate was successfully added by looking for contents of
# webservices.crt in /etc/ssl/certs/ca-certificates.crt
# e.g. `cat /etc/ssl/certs/ca-certificates.crt | grep <first-line-of-cert>`
COPY webservices/core/certs/webservices.crt /usr/local/share/ca-certificates/webservices.crt
RUN update-ca-certificates
# Set the environment variable for the Python Requests package to trust this certificate
# The Requests package is used by fastapi-keycloak, FastAPI, and other dependencies
# https://requests.readthedocs.io/en/latest/user/advanced/#ssl-cert-verification
ENV REQUESTS_CA_BUNDLE=/usr/local/share/ca-certificates/webservices.crt

COPY ./alembic.ini alembic.ini
COPY ./pyproject.toml pyproject.toml
COPY ./alembic alembic
COPY ./stubs stubs
COPY ./tests tests
COPY ./webservices webservices

ENV PYTHONPATH=./

EXPOSE 8883

FROM python:3.11-slim as production

LABEL maintainer="Brent S <contact@webservices.com>"

# Ensure curl is available for healthcheck via curl. Add re2 compiled dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    gcc \
    g++ \
    libre2-dev \
    libpq-dev

# Cleanup the apt cache to reduce image size
RUN apt-get purge -y --auto-remove
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /webservices/backend

COPY ./start.sh start.sh
RUN chmod +x start.sh

COPY ./gunicorn_conf.py gunicorn_conf.py

COPY ./start-reload.sh start-reload.sh
RUN chmod +x start-reload.sh

COPY ./prestart.sh prestart.sh
RUN chmod +x prestart.sh

COPY --from=requirements-stage /tmp/requirements.txt /webservices/backend/requirements.txt

# Caching with BuildKit: https://pythonspeed.com/articles/docker-cache-pip-downloads/
# In you dev environment, be sure BuildKit is active using an enivornment variable:
# export DOCKER_BUILDKIT=1
# This setting may be permenently enabled on Ubuntu by adding it to user profile config
# via `gedit ~/.profile` in terminal
RUN --mount=type=cache,target=/root/.cache \
  pip install --upgrade -r requirements.txt

# Alternate caching method without BuildKit as recommended on FastAPI docs:
# https://fastapi.tiangolo.com/deployment/docker/#docker-cache
#RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt

# Add self-signed public certificate to trusted certificate autorites.
# This allows TLS communication between other services like Keycloak
# You can verify the certificate was successfully added by looking for contents of
# webservices.crt in /etc/ssl/certs/ca-certificates.crt
# e.g. `cat /etc/ssl/certs/ca-certificates.crt | grep <first-line-of-cert>`
COPY webservices/core/certs/webservices.crt /usr/local/share/ca-certificates/webservices.crt
RUN update-ca-certificates
# Set the environment variable for the Python Requests package to trust this certificate
# The Requests package is used by fastapi-keycloak, FastAPI, and other dependencies
# https://requests.readthedocs.io/en/latest/user/advanced/#ssl-cert-verification
ENV REQUESTS_CA_BUNDLE=/usr/local/share/ca-certificates/webservices.crt

COPY ./alembic.ini alembic.ini
COPY ./pyproject.toml pyproject.toml
COPY ./alembic alembic
COPY ./webservices webservices

ENV PYTHONPATH=./

EXPOSE 8883