#!/usr/bin/env bash
set -euo pipefail

# If launched by JupyterHub, these env vars will be present.
if [[ -n "${JUPYTERHUB_SERVICE_URL:-}" ]]; then
  echo "[start.sh] Detected JupyterHub environment -> starting jupyterhub-singleuser"
  exec jupyterhub-singleuser "$@"
fi

# Standalone mode (plain docker run)
echo "[start.sh] No JupyterHub env detected -> starting JupyterLab (standalone)"

# Token persistence: save/load from a file
TOKEN_FILE="${HOME}/.jupyter/jupyter_token"
mkdir -p "${HOME}/.jupyter"

if [[ -z "${JUPYTER_TOKEN:-}" ]]; then
  if [[ -f "${TOKEN_FILE}" ]]; then
    # Reuse existing token
    JUPYTER_TOKEN=$(cat "${TOKEN_FILE}")
    echo "[start.sh] Loaded existing token from ${TOKEN_FILE}"
  else
    # Generate a new random token
    JUPYTER_TOKEN=$(openssl rand -hex 24)
    echo "${JUPYTER_TOKEN}" > "${TOKEN_FILE}"
    chmod 600 "${TOKEN_FILE}"
    echo "[start.sh] Generated new token and saved to ${TOKEN_FILE}"
  fi
  echo "[start.sh] Jupyter token: ${JUPYTER_TOKEN}"
  echo "[start.sh] Access JupyterLab at: http://127.0.0.1:${PORT:-8888}/lab?token=${JUPYTER_TOKEN}"
else
  # User provided a token via env var - save it for future runs
  echo "${JUPYTER_TOKEN}" > "${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}"
  echo "[start.sh] Saved user-provided token to ${TOKEN_FILE}"
  echo "[start.sh] Access JupyterLab at: http://127.0.0.1:${PORT:-8888}/lab?token=${JUPYTER_TOKEN}"
fi

exec jupyter lab \
  --ip=0.0.0.0 \
  --port="${PORT:-8888}" \
  --no-browser \
  --ServerApp.token="${JUPYTER_TOKEN}" \
  --ServerApp.password="${JUPYTER_PASSWORD:-}" \
  --ServerApp.allow_origin="*" \
  --ServerApp.allow_remote_access=True \
  --ServerApp.root_dir="${HOME}" \
  "$@"