# JupyterLab + PyTorch + 3D Slicer + VS Code Docker Image

A comprehensive Docker image combining JupyterLab, PyTorch with CUDA support, 3D Slicer medical imaging platform, and VS Code in a browser-accessible environment with VNC desktop.

## Acknowledgements

This project builds upon and integrates several excellent open-source projects:

- **[jupyter-remote-desktop-proxy](https://github.com/jupyterhub/jupyter-remote-desktop-proxy)**: The foundation for providing VNC desktop access through Jupyter
- **[PyTorch Docker Images](https://hub.docker.com/r/pytorch/pytorch)**: Official PyTorch base images with CUDA support
- **[3D Slicer](https://www.slicer.org/)**: Open-source medical image computing platform
- **[code-server](https://github.com/coder/code-server)**: VS Code in the browser by Coder

Special thanks to the JupyterHub, PyTorch, 3D Slicer, and VS Code communities for their outstanding work.

## Features

- **PyTorch 2.3.1** with CUDA 12.1 and cuDNN 8 support
- **JupyterLab 4.5+** with JupyterHub integration
- **Python and R kernels** for Jupyter notebooks
- **3D Slicer 5.10.0** medical imaging platform with dark theme
- **VS Code** (code-server) in the browser with Python and Jupyter extensions
- **XFCE4 Desktop** accessible via browser with dark theme
- **Persistent authentication tokens** across container restarts
- **Auto-start 3D Slicer** in fullscreen mode when VNC desktop opens
- **Corporate proxy and certificate support**
- **GPU support** for PyTorch and CUDA workloads
- **Common development tools**: vim, nano, git, tmux, htop, and more

## Building the Image

### Basic Build

```bash
docker build -t jupyter_rad:dev .
```

### Build with Corporate Proxy

If you're behind a corporate proxy, use these build arguments:

```bash
docker build \
  --build-arg http_proxy=http://proxy.company.com:8080 \
  --build-arg https_proxy=http://proxy.company.com:8080 \
  --build-arg HTTP_PROXY=http://proxy.company.com:8080 \
  --build-arg HTTPS_PROXY=http://proxy.company.com:8080 \
  --build-arg no_proxy=localhost,127.0.0.1 \
  --build-arg NO_PROXY=localhost,127.0.0.1 \
  -t jupyter_rad:dev .
```

### Build with Corporate Certificates

If you need to add corporate CA certificates:

1. Create a folder containing your `.crt` files (e.g., `./corporate-certs/`)
2. Build with the `CERTS_FOLDER` argument:

```bash
docker build \
  --build-arg CERTS_FOLDER=./corporate-certs \
  -t jupyter_rad:dev .
```

### Build with Local 3D Slicer

If you already have 3D Slicer downloaded locally and want to use it instead of downloading during build:

1. Extract your Slicer archive to a folder (e.g., `./local-slicer/Slicer-5.10.0-linux-amd64/`)
2. Build with the `LOCAL_SLICER_FOLDER` argument:

```bash
docker build \
  --build-arg LOCAL_SLICER_FOLDER=./local-slicer \
  -t jupyter_rad:dev .
```

**Note**: The folder should contain the extracted Slicer directory (e.g., `Slicer-5.10.0-linux-amd64/`).

### Combined: Proxy + Certificates + Local Slicer

```bash
docker build \
  --build-arg http_proxy=http://proxy.company.com:8080 \
  --build-arg https_proxy=http://proxy.company.com:8080 \
  --build-arg CERTS_FOLDER=./corporate-certs \
  --build-arg LOCAL_SLICER_FOLDER=./local-slicer \
  -t jupyter_rad:dev .
```

## Running the Container

### GPU + Memory + Storage:

```bash
docker run --rm -it \
  --gpus all \
  --shm-size=2g \
  -p 8888:8888 \
  -v $PWD/data:/home/jovyan/work \
  -v $PWD/notebooks:/home/jovyan/notebooks \
  jupyter_rad:dev
```

### Docker Run Flags Explained

| Flag | Purpose |
|------|---------|
| `--rm` | Automatically remove container when it stops |
| `-it` | Interactive terminal (see logs, enable Ctrl+C) |
| `--gpus all` | Enable all GPUs for CUDA workloads |
| `--shm-size=2g` | Increase shared memory to 2GB (prevents Slicer crashes) |
| `-p 8888:8888` | Expose JupyterLab port |
| `-v <host>:<container>` | Mount volumes for persistent storage |

## Accessing the Services

Access the services in your browser:

- **JupyterLab**: http://localhost:8888/lab?token=YOUR_TOKEN
- **VNC Desktop (3D Slicer)**: http://localhost:8888/desktop
- **VS Code**: http://localhost:8888/vscode

The authentication token is displayed when the container starts.

## JupyterHub Integration

### Kubernetes JupyterHub Setup

This image is designed to work with [JupyterHub on Kubernetes](https://z2jh.jupyter.org/). Configure it in your `values.yaml` file:

#### Configuration in values.yaml

```yaml
singleuser:
  defaultUrl: "/lab"
  
  image:
    name: your-registry.com/jupyter_rad
    tag: latest
  
  # Shared memory for 3D Slicer (required)
  storage:
    extraVolumes:
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: 2Gi
    extraVolumeMounts:
      - name: shm
        mountPath: /dev/shm
  
  # Resource limits
  memory:
    limit: 16G
    guarantee: 8G
  
  cpu:
    limit: 8
    guarantee: 4
  
  # Storage - mount to /home/jovyan/work to preserve configs
  storage:
    capacity: 10Gi
    homeMountPath: /home/jovyan/work
  
  # User permissions
  uid: 1000
  fsGid: 100
```

### Deploying JupyterHub

Install or upgrade your JupyterHub deployment:

```bash
# Add JupyterHub Helm repository
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update

# Install
helm install jhub jupyterhub/jupyterhub \
  --namespace jhub \
  --create-namespace \
  --values values.yaml \
  --version 3.3.7

# Upgrade existing deployment
helm upgrade --cleanup-on-fail jhub jupyterhub/jupyterhub \
  --namespace jhub \
  --values values.yaml \
  --version 3.3.7
```

### Accessing Services in JupyterHub

Once users spawn their server, they can access:

- **JupyterLab**: Default interface at `/user/<username>/lab`
- **VNC Desktop (3D Slicer)**: `/user/<username>/desktop`
- **VS Code**: `/user/<username>/vscode`

The 3D Slicer application will auto-start in the VNC desktop.

## User Configuration

### Default User

- **Username**: `jovyan`
- **UID**: `1000`
- **GID**: `100` (users group)
- **Home**: `/home/jovyan`
- **Sudo**: Passwordless sudo enabled

### Pre-configured Features

#### 3D Slicer
- Auto-starts in fullscreen mode
- Dark theme pre-configured
- WebEngine disabled (prevents container crashes)
- Extensions can be installed manually
- Full write access to `/opt/Slicer` directory

#### VS Code (code-server)
- Dark theme pre-configured
- Python extension installed
- Jupyter extension installed
- Settings persisted in `~/.local/share/code-server`

#### XFCE Desktop
- Dark Adwaita theme
- Dark background
- 3D Slicer desktop shortcut



## Development

### Modifying the Image

1. Edit the `Dockerfile` or configuration files
2. Rebuild: `docker build -t jupyter_rad:dev .`
3. Test: `docker run --rm -it --shm-size=2g -p 8888:8888 jupyter_rad:dev`

### Key Configuration Files

- `Dockerfile`: Main build definition
- `start.sh`: Container entrypoint script
- `SlicerRC.py`: 3D Slicer startup configuration
- `Slicer.ini`: Slicer preferences
- `code-server-settings.json`: VS Code settings
- `xfce4-*.xml`: Desktop environment themes
- `jupyter_remote_desktop_proxy/share/xstartup`: VNC session startup

## License

This project maintains the original licenses of its components. See individual component documentation for details.
