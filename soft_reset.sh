#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

export DOCKER_BUILDKIT=1

# Export all current .env values. Passwords and secrets will be re-used so that Postgres
# and other stateful containers don't need to be wiped because new passwords/secrets were
# generated
if [[ -f ".env" ]]; then
  # Store the current .env settings
  export $(grep -v '^#' .env | xargs)
  # Apply override settings, if present
  HTTPS_PORT=${HTTPS_PORT_NEW:-$HTTPS_PORT}
  export HTTPS_PORT
  DOMAIN=${DOMAIN_NEW:-$DOMAIN}
  export DOMAIN
fi

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

# Run the .env and key initialization script
/bin/bash ./initialize_env_and_cert.sh

# Stop any currently running containers for this project.
# Remove containers for services not defined in the Compose file.
docker compose down --remove-orphans
