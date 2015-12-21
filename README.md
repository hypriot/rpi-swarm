# rpi-swarm

Raspberry Pi compatible Docker image with [Docker Swarm](https://github.com/docker/swarm).

Run all the commands from within the project root directory.

### Build Details
- [Source Project Page](https://github.com/hypriot)
- [Source Repository](https://github.com/hypriot/rpi-swarm)
- [Dockerfile](https://github.com/hypriot/rpi-swarm/blob/master/Dockerfile)
- [DockerHub] (https://registry.hub.docker.com/u/hypriot/rpi-swarm/)


#### Build the Docker Image
```bash
make build
```

#### Run the Docker Image and get the version of the installed `Docker Swarm`
```bash
make version
```

#### Push the Docker Image to the Docker Hub
* First use a `docker login` with username, password and email address
* Second push the Docker Image to the official Docker Hub

```bash
make push
```

## License

The MIT License (MIT)

Copyright (c) 2015 Hypriot
