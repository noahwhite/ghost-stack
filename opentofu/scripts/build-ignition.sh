#!/bin/bash
set -euo pipefail

docker run --rm -i \
  -v "$PWD:/workspace" \
  quay.io/coreos/butane:release \
  --pretty --strict \
  -o /workspace/opentofu/modules/vultr/instance/userdata/ghost.ign.tpl \
  /workspace/opentofu/modules/vultr/instance/userdata/ghost.bu

echo "✅ Butane compiled ghost.bu → ghost.ign.tpl"