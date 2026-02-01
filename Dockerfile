# -----------------------------------------------------------------------------
# PyTorch + Jupyter Remote Desktop Proxy + 3D Slicer + VS Code (code-server)
# -----------------------------------------------------------------------------

FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# -------------------------
# Proxy and certificate configuration
# -------------------------
ARG http_proxy
ARG https_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG no_proxy
ARG NO_PROXY
ARG CERTS_FOLDER=./certs/

# Set proxy environment variables if provided
ENV http_proxy=${http_proxy}
ENV https_proxy=${https_proxy}
ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV no_proxy=${no_proxy}
ENV NO_PROXY=${NO_PROXY}

# Copy and install certificates if CERTS_FOLDER is provided
COPY ${CERTS_FOLDER} /tmp/custom_certs/
RUN set -eux; \
    cert_count=$(find /tmp/custom_certs -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | wc -l); \
    if [ "$cert_count" -gt 0 ]; then \
      echo "Installing custom certificates..."; \
      cp /tmp/custom_certs/*.crt /usr/local/share/ca-certificates/ 2>/dev/null || true; \
      cp /tmp/custom_certs/*.pem /usr/local/share/ca-certificates/ 2>/dev/null || true; \
      # Rename .pem to .crt if needed
      for pemfile in /usr/local/share/ca-certificates/*.pem; do \
        if [ -f "$pemfile" ]; then \
          mv "$pemfile" "${pemfile%.pem}.crt"; \
        fi; \
      done; \
      update-ca-certificates; \
      # Configure pip to use system certificates
      mkdir -p /etc/pip; \
      echo "[global]" > /etc/pip.conf; \
      echo "cert = /etc/ssl/certs/ca-certificates.crt" >> /etc/pip.conf; \
      # Configure conda to use system certificates
      conda config --system --set ssl_verify /etc/ssl/certs/ca-certificates.crt || true; \
      echo "Custom certificates installed successfully."; \
    else \
      echo "No custom certificates found, skipping certificate installation."; \
    fi; \
    rm -rf /tmp/custom_certs; \
    # Configure pip proxy settings if provided
    if [ -n "${http_proxy}${https_proxy}" ]; then \
      mkdir -p /etc/pip; \
      if [ ! -f /etc/pip.conf ]; then echo "[global]" > /etc/pip.conf; fi; \
      if [ -n "${http_proxy}" ]; then \
        echo "proxy = ${http_proxy}" >> /etc/pip.conf; \
      elif [ -n "${https_proxy}" ]; then \
        echo "proxy = ${https_proxy}" >> /etc/pip.conf; \
      fi; \
      echo "Pip proxy configured."; \
    fi; \
    # Configure conda proxy settings if provided
    if [ -n "${http_proxy}${https_proxy}" ]; then \
      if [ -n "${http_proxy}" ]; then \
        conda config --system --set proxy_servers.http "${http_proxy}" || true; \
      fi; \
      if [ -n "${https_proxy}" ]; then \
        conda config --system --set proxy_servers.https "${https_proxy}" || true; \
      fi; \
      echo "Conda proxy configured."; \
    fi

# -------------------------
# User configuration (Jupyter-style)
# -------------------------
ARG NB_USER=jovyan
ARG NB_UID=1000
ARG NB_GID=100

ENV NB_USER=${NB_USER}
ENV NB_UID=${NB_UID}
ENV NB_GID=${NB_GID}
ENV HOME=/home/${NB_USER}

# Jupyter dirs (keep them under HOME; we will create+chown them as root)
ENV JUPYTER_DATA_DIR=${HOME}/.local/share/jupyter
ENV JUPYTER_RUNTIME_DIR=${HOME}/.local/share/jupyter/runtime
ENV JUPYTER_CONFIG_DIR=${HOME}/.jupyter

# Make sure conda is on PATH (PyTorch images typically ship it at /opt/conda)
ENV PATH=/opt/conda/bin:${PATH}

# -------------------------
# System packages: desktop + VNC + websockify + browser + runtime libs
# -------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      git \
      sudo \
      locales \
      vim \
      nano \
      htop \
      tmux \
      tree \
      less \
      jq \
      zip \
      unzip \
      rsync \
      openssh-client \
      build-essential \
      cmake \
      gdb \
      net-tools \
      iputils-ping \
      dbus-x11 \
      xauth \
      x11-xserver-utils \
      xfce4 \
      xfce4-terminal \
      tigervnc-standalone-server \
      tigervnc-common \
      websockify \
      firefox \
      gnome-themes-extra \
      gtk2-engines-murrine \
      libgl1 \
      libxrender1 \
      libxext6 \
      libsm6 \
      libglib2.0-0 \
      libxcb-icccm4 \
      libxcb-image0 \
      libxcb-keysyms1 \
      libxcb-randr0 \
      libxcb-render-util0 \
      libxcb-shape0 \
      libxcb-xfixes0 \
      libxcb-xinerama0 \
      libxkbcommon-x11-0 \
      libdbus-1-3 \
      libglu1-mesa \
      libnss3 \
      libpcre2-16-0 \
      libxtst6 \
      libxt6 \
      libx11-6 \
      libxss1 \
      ; \
    rm -rf /var/lib/apt/lists/*; \
    locale-gen en_US.UTF-8

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      # X11 core + XCB
      libx11-6 libxext6 libxrender1 libxss1 libxt6 libxtst6 \
      libxcb1 libxkbcommon-x11-0 \
      libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
      libxcb-render-util0 libxcb-shape0 libxcb-xfixes0 libxcb-xinerama0 \
      # OpenGL
      libgl1 libglu1-mesa libglx0 \
      # Audio
      libasound2 libpulse0 \
      # Common runtime
      libdbus-1-3 libglib2.0-0 libnss3 libpcre2-16-0 zlib1g \
      ; \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# -------------------------
# Create a non-root user (idempotent for GID collisions)
# -------------------------
RUN set -eux; \
    existing_group="$(getent group "${NB_GID}" | cut -d: -f1 || true)"; \
    if [ -z "${existing_group}" ]; then \
      groupadd --gid "${NB_GID}" "${NB_USER}"; \
    fi; \
    if ! id -u "${NB_USER}" >/dev/null 2>&1; then \
      useradd --uid "${NB_UID}" --gid "${NB_GID}" -m -s /bin/bash "${NB_USER}"; \
    fi; \
    mkdir -p "${HOME}"; \
    chown -R "${NB_UID}:${NB_GID}" "${HOME}"; \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${NB_USER}"; \
    chmod 0440 "/etc/sudoers.d/${NB_USER}"

# -------------------------
# Create Jupyter runtime/config/cache dirs AS ROOT, then chown
# (must be before USER jovyan, otherwise permission issues)
# -------------------------
RUN set -eux; \
    mkdir -p \
      "${HOME}/.local/share" \
      "${HOME}/.jupyter" \
      "${HOME}/.config" \
      "${HOME}/.cache"; \
    chown -R "${NB_UID}:${NB_GID}" \
      "${HOME}/.local" \
      "${HOME}/.jupyter" \
      "${HOME}/.config" \
      "${HOME}/.cache"

# -------------------------
# Jupyter + proxies (avoid conda solver)
# -------------------------
RUN set -eux; \
    pip install --no-cache-dir \
      "jupyterlab>=4,<5" \
      "jupyterhub>=4,<5" \
      "jupyter-server-proxy>=4,<5" \
      jupyter-vscode-proxy \
      jupyter-remote-desktop-proxy

# Replace the default xstartup with our custom one that auto-starts Slicer
COPY jupyter_remote_desktop_proxy/share/xstartup /tmp/xstartup
RUN set -eux; \
    XSTARTUP_PATH=$(find /opt/conda -path "*/jupyter_remote_desktop_proxy/share/xstartup" 2>/dev/null | head -1); \
    if [ -n "${XSTARTUP_PATH}" ]; then \
      cp /tmp/xstartup "${XSTARTUP_PATH}"; \
      chmod +x "${XSTARTUP_PATH}"; \
      echo "Replaced xstartup at ${XSTARTUP_PATH}"; \
    else \
      echo "ERROR: Could not find xstartup file"; \
      exit 1; \
    fi; \
    rm /tmp/xstartup

# -------------------------
# R and IRkernel for Jupyter
# -------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      r-base \
      r-base-dev \
      libcurl4-openssl-dev \
      libssl-dev \
      libxml2-dev \
      libfontconfig1-dev \
      libharfbuzz-dev \
      libfribidi-dev \
      libfreetype6-dev \
      libpng-dev \
      libtiff5-dev \
      libjpeg-dev \
      ; \
    rm -rf /var/lib/apt/lists/*

# Install IRkernel and essential R packages
RUN R -e "install.packages(c('IRkernel', 'tidyverse', 'data.table', 'ggplot2', 'devtools'), repos='https://cloud.r-project.org/')" && \
    R -e "IRkernel::installspec(user = FALSE)"

# -------------------------
# code-server (web VS Code backend)
# -------------------------
RUN set -eux; \
    curl -fsSL https://code-server.dev/install.sh | sh

ENV CODE_SERVER_EXTENSIONS_DIR=/opt/code-server/extensions
RUN set -eux; \
    mkdir -p "${CODE_SERVER_EXTENSIONS_DIR}"; \
    code-server --extensions-dir "${CODE_SERVER_EXTENSIONS_DIR}" --install-extension ms-python.python; \
    code-server --extensions-dir "${CODE_SERVER_EXTENSIONS_DIR}" --install-extension ms-toolsai.jupyter

# -------------------------
# 3D Slicer install (stable release)
# -------------------------
ARG SLICER_URL="https://download.slicer.org/download?os=linux&stability=release"
ARG LOCAL_SLICER_FOLDER=""

# Copy local Slicer if provided
RUN mkdir -p /tmp/local_slicer_temp
COPY --chown=${NB_UID}:${NB_GID} ${LOCAL_SLICER_FOLDER:-certs/.gitkeep} /tmp/local_slicer_temp/

RUN set -eux; \
    if [ -d "/tmp/local_slicer_temp" ] && [ "$(find /tmp/local_slicer_temp -mindepth 1 -type d -name 'Slicer*' | wc -l)" -gt 0 ]; then \
      echo "Using local Slicer installation..."; \
      slicer_dir=$(find /tmp/local_slicer_temp -mindepth 1 -maxdepth 2 -type d -name 'Slicer*' | head -1); \
      if [ -n "${slicer_dir}" ]; then \
        mv "${slicer_dir}" /opt/Slicer; \
      else \
        echo "ERROR: No Slicer directory found in local folder"; \
        exit 1; \
      fi; \
    else \
      echo "Downloading Slicer from ${SLICER_URL}..."; \
      SLICER_TGZ=/tmp/slicer.tar.gz; \
      # Configure wget for proxy and certificates
      WGET_OPTS="--no-check-certificate"; \
      if [ -n "${http_proxy:-}" ]; then \
        WGET_OPTS="${WGET_OPTS} -e use_proxy=yes -e http_proxy=${http_proxy}"; \
      fi; \
      if [ -n "${https_proxy:-}" ]; then \
        WGET_OPTS="${WGET_OPTS} -e https_proxy=${https_proxy}"; \
      fi; \
      wget ${WGET_OPTS} -O "${SLICER_TGZ}" "${SLICER_URL}"; \
      topdir="$(tar -tzf "${SLICER_TGZ}" | head -1 | cut -d/ -f1)"; \
      tar -xzf "${SLICER_TGZ}" -C /opt; \
      rm -f "${SLICER_TGZ}"; \
      mv "/opt/${topdir}" /opt/Slicer; \
    fi; \
    rm -rf /tmp/local_slicer_temp; \
    ln -sf /opt/Slicer/Slicer /usr/local/bin/Slicer; \
    chown -R "${NB_UID}:${NB_GID}" /opt/Slicer; \
    \
    icon_path="$(find /opt/Slicer -maxdepth 6 -type f -iname 'slicer*.png' | head -1 || true)"; \
    if [ -n "${icon_path}" ]; then \
      cp -f "${icon_path}" /usr/share/pixmaps/slicer.png; \
    fi; \
    \
    cat > /usr/share/applications/Slicer.desktop <<'EOF'

[Desktop Entry]
Version=1.0
Type=Application
Name=3D Slicer
Comment=Medical image computing platform
Exec=/opt/Slicer/Slicer
Icon=/usr/share/pixmaps/slicer.png
Terminal=false
Categories=Education;Science;MedicalSoftware;
EOF
RUN chmod 0644 /usr/share/applications/Slicer.desktop

# Register Slicer library paths with the dynamic linker (deterministic: resolve Slicer-* dir)
RUN set -eux; \
    slicer_libdir="$(find /opt/Slicer/lib -maxdepth 1 -type d -name 'Slicer-*' | head -n 1)"; \
    test -n "${slicer_libdir}"; \
    printf '%s\n' \
      "${slicer_libdir}" \
      /opt/Slicer/lib \
      /opt/Slicer/bin \
      > /etc/ld.so.conf.d/slicer.conf; \
    ldconfig; \
    # quick sanity check: these should now be resolvable by the loader cache
    ldconfig -p | grep -E 'libqSlicerApp\.so|libQt5Core\.so\.5' || true


# Put a clickable Slicer icon onto the desktop for NB_USER
RUN set -eux; \
    mkdir -p "${HOME}/Desktop"; \
    cp -f /usr/share/applications/Slicer.desktop "${HOME}/Desktop/Slicer.desktop"; \
    chmod +x "${HOME}/Desktop/Slicer.desktop"; \
    chown -R "${NB_UID}:${NB_GID}" "${HOME}/Desktop"

# -------------------------
# Configure dark themes for XFCE, code-server, and 3D Slicer
# -------------------------
# XFCE dark theme
RUN set -eux; \
    mkdir -p "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml"; \
    chown -R "${NB_UID}:${NB_GID}" "${HOME}/.config"

COPY xfce4-desktop.xml "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
COPY xfce4-xsettings.xml "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"

RUN chown "${NB_UID}:${NB_GID}" \
    "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" \
    "${HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"

# code-server dark theme
RUN mkdir -p "${HOME}/.local/share/code-server/User"
COPY code-server-settings.json "${HOME}/.local/share/code-server/User/settings.json"
RUN chown -R "${NB_UID}:${NB_GID}" "${HOME}/.local/share/code-server"

# 3D Slicer dark theme and fullscreen config
RUN mkdir -p "${HOME}/.config/NA-MIC" "${HOME}/.config/slicer.org"
COPY SlicerRC.py "${HOME}/.slicerrc.py"
COPY Slicer.ini "${HOME}/.config/slicer.org/Slicer.ini"
RUN chown -R "${NB_UID}:${NB_GID}" "${HOME}/.slicerrc.py" \
                                     "${HOME}/.config/slicer.org" \
                                     "${HOME}/.config/NA-MIC"

# -------------------------
# Copy startup script that supports both JupyterHub and standalone docker run
# -------------------------
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh && chown ${NB_UID}:${NB_GID} /usr/local/bin/start.sh

# -------------------------
# Final permission fix - ensure all home directories are owned by jovyan
# -------------------------
RUN chown -R "${NB_UID}:${NB_GID}" "${HOME}"

# -------------------------
# Jupyter defaults
# -------------------------
EXPOSE 8888
USER ${NB_USER}
WORKDIR ${HOME}
CMD ["/usr/local/bin/start.sh"]