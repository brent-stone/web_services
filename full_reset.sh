#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

export DOCKER_BUILDKIT=1

# Certificate and environment variable paths used throughout the project
declare -a PathArray=(
  ".env" \
  "./backend/.test.env" \
  "./certs/webservices.crt" \
  "./certs/webservices.key" \
  "./keycloak/certs/webservices.crt" \
  "./keycloak/certs/webservices.key" \
  "./backend/webservices/core/certs/webservices.crt" \
)
# Iterate over the paths and remove the files if present
# The [@] operator is get all elements, space-separated
for l_path in "${PathArray[@]}"; do
  if [ -f "$l_path" ]; then
  rm "$l_path"
  fi
done

# Run the initialization script
/bin/bash ./initialize_env_and_cert.sh

# Stop any currently running containers for this project.
# Remove containers for services not defined in the Compose file.
# Remove named volumes declared in the volumes section of the Compose file and anonymous
# volumes attached to containers.
docker compose down --remove-orphans --volumes
