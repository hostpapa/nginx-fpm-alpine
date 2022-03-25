# Nginx FPM Alpine Docker Image

This image is best used in environments where having a **single container** that
can serve requests is preferred over a multi-container setup. The focus of this
base image is to be as small as possible for extension by other projects.

## Building the Image

Tagged versions of this image are automatically built, tagged and pushed to
[Github Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
and are available in the **packages** area of this repository.

This repository and the built images follow [Semantic
Versioning](https://semver.org/).

To build localy, run

```
docker build -t hostpapa/nginx-fpm-alpine .
```

## How to use this image

This image does _not_ have what's needed to satisfy SSL requests. It's intended
to sit behind an SSL prox of some sort such as our [Nginx SSL
Proxy](https://github.com/hostpapa/nginx-ssl-proxy) or the ingress of your
hosting environment.

### Configuration

- [ ] Flesh this out with what needs to be set up
