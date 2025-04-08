# Deploid

## Testing with Docker

To test these scripts in a clean environment, you can use Docker. This will allow you to test the setup process from scratch without affecting your local system.

### Prerequisites

- Docker installed on your system

### Building the Test Environment

1. Build the Docker image

```bash
docker build -t deploid .
```

1. Run the container

```bash
docker run -it --privileged deploid
```

The `--privileged` flag is required because the scripts will install and manage Docker inside the container.

### Inside the Container

Once inside the container, you can:

- Run `./setup.sh` to test the initial setup process
- Run `./update.sh` to test the update process
- Test individual scripts as needed

### Notes

- The container starts with a clean Ubuntu 22.04 installation
- All installation and configuration will be handled by the scripts
- The container has a non-root user (`testuser`) with sudo privileges
- All scripts are already made executable in the container
