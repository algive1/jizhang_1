#!/usr/bin/env bash
# Run on the production host: ./scripts/deploy.sh repository@sha256:... 1.0.1
set -euo pipefail
cd "$(dirname "$0")/.."
image=${1:?Pinned image is required}
version=${2:?Version is required}
[[ "$image" =~ ^[a-zA-Z0-9._:/-]+@sha256:[a-f0-9]{64}$ ]] || { echo 'Invalid image digest'; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid version'; exit 1; }
compose=(docker compose -f docker-compose.production.yml)
container=$("${compose[@]}" ps -q app)
[[ -n "$container" ]] || { echo 'An existing backend is required'; exit 1; }
previous=$(docker inspect -f '{{.Config.Image}}' "$container")
previous_version=$(docker exec "$container" node -p 'process.env.BACKEND_VERSION || "development"')
"${compose[@]}" exec -T app node scripts/backup.mjs
export BACKEND_IMAGE="$image" BACKEND_VERSION="$version"
"${compose[@]}" pull app
restore(){ export BACKEND_IMAGE="$previous" BACKEND_VERSION="$previous_version"; "${compose[@]}" up -d --no-deps --no-build app; echo 'Previous image restored. Database is retained; incompatible migrations need a reviewed restore from the verified backup.'; }
if ! "${compose[@]}" up -d --no-deps --no-build app; then restore; exit 1; fi
for attempt in $(seq 1 30); do
  if "${compose[@]}" exec -T app node -e "fetch('http://127.0.0.1:8787/ready').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"; then
    echo "Backend $version is ready. Persist BACKEND_IMAGE and BACKEND_VERSION in the deployment environment."
    exit 0
  fi
  sleep 2
done
restore
exit 1
