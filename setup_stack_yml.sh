#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

SWARM_YAML=$(docker compose config)

{
  echo 'version: "3.8"';
  echo '# Initialize swarm with "docker swarm init"';
  echo '# Run swarm with "docker stack deploy -c stack_config.yml autoai-stack"';
  echo '# Shutdown the stack with "docker stack rm autoai-stack"';
  echo '# See stack status with "docker stack ps autoai-stack"';
  echo '# If you need to go back to docker compose, totally shutdown swarm with "docker swarm leave --force"';
  echo '#   That will free up ports that were reserved by the swarm deployment';
  echo '# IMPORTANT! Be sure to do these before starting the stack the first time';
  echo '# 1. Run "docker swarm init" if you do not already have a swarm manager';
  echo '# 2. Delete all instances of "depends_on" entries in the yml';
  echo '# 3. Run "docker compose build" to ensure all images are present';
  echo "${SWARM_YAML}";
} > stack_config.yml