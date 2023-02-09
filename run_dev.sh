#! /bin/bash
# stop execution instantly on non-zero status. This is to know location of error
set -e

docker compose up --build