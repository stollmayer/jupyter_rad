#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# Restore configs if missing (e.g., when /home/jovyan is mounted)
# -------------------------
restore_configs() {
  echo "[start.sh] Checking for missing configs (may happen when volumes are mounted)..."
  
  # Restore Slicer configs
  if [[ ! -f "${HOME}/.slicerrc.py" ]]; then
    echo "[start.sh] Restoring Slicer RC file..."
    cp /tmp/config_backups/.slicerrc.py "${HOME}/.slicerrc.py" 2>/dev/null || true
  fi
  
  if [[ ! -f "${HOME}/.config/slicer.org/Slicer.ini" ]]; then
    echo "[start.sh] Restoring Slicer config..."
    mkdir -p "${HOME}/.config/slicer.org"
    cp /tmp/config_backups/Slicer.ini "${HOME}/.config/slicer.org/Slicer.ini" 2>/dev/null || true
  fi
  
  # Restore XFCE configs
  if [[ ! -f "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" ]]; then
    echo "[start.sh] Restoring XFCE desktop config..."
    mkdir -p "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"
    cp /tmp/config_backups/xfce4-desktop.xml "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" 2>/dev/null || true
    cp /tmp/config_backups/xsettings.xml "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" 2>/dev/null || true
  fi
  
  # Restore code-server configs
  if [[ ! -f "${HOME}/.local/share/code-server/User/settings.json" ]]; then
    echo "[start.sh] Restoring code-server config..."
    mkdir -p "${HOME}/.local/share/code-server/User"
    cp /tmp/config_backups/code-server-settings.json "${HOME}/.local/share/code-server/User/settings.json" 2>/dev/null || true
  fi
  
  # Restore Desktop shortcuts
  if [[ ! -f "${HOME}/Desktop/Slicer.desktop" ]]; then
    echo "[start.sh] Restoring Slicer desktop shortcut..."
    mkdir -p "${HOME}/Desktop"
    cp /usr/share/applications/Slicer.desktop "${HOME}/Desktop/Slicer.desktop" 2>/dev/null || true
    chmod +x "${HOME}/Desktop/Slicer.desktop" 2>/dev/null || true
  fi
  
  echo "[start.sh] Config restoration complete."
}

# Run config restoration
restore_configs

# -------------------------
# JupyterHub vs Standalone detection
# -------------------------
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