# Nginx FPM Alpine Docker Image

- PHP Version: 8.0.X
- Nginx Version: 1.20

This image is best used in environments where having a **single container** that
can serve requests is preferred over a multi-container setup. The focus of this
base image is to be as small as possible for extension by other projects.

This is a base _Web Image_ which combines FPM and Nginx into a single image,
starting them up at the end with Supervisord. By having a single container, we
can simplify deployments. For example, in Kubernetes, we don't have to worry
about shared volumes and init containers.

A typical Nginx setup within this container is setup to ONLY listen on Port 80
(non-ssl) with the expectation that SSL is terminated at a load balancer and
then proxied to this container. This allows this container to be simpler and
leave SSL creation and termination to the deployment environment. Even in a
Kubernetes setup, a Service Mesh SHOULD be used to enforce mTLS encrypting all
internal traffic. Even in this scenario, we _still_ only need a container that
listed on Port 80.

This image _starts off_ with the official PHP FPM image as, between Nginx and
FPM, FPM is more complex to setup. The best of both Nginx and FPM containers
have been combined into this image from a functionality perspective (nginx
templates with envsubst, etc).

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

You can run this image in isolation to test it with

```
docker run -p 8080:80 hostpapa/nginx-fpm-alpine
```

Once running in the foreground, you can hit http://localhost:8080/ and receive a
`404 Not Found` as that's all the image returns out of the box.

## How to use this image

This image does _not_ have what's needed to satisfy SSL requests. It's intended
to sit behind an SSL prox of some sort such as our [Nginx SSL
Proxy](https://github.com/hostpapa/nginx-ssl-proxy) or the ingress of your
hosting environment.

### PHP Configuration

TODO: What to setup, where to copy

### Nginx Configuration

### Configuration

- [ ] Flesh this out with what needs to be set up
- [ ] `example_configs`
- [ ] Note about environment variables in FPM config
- [ ] Add documentation on the entrypoints folder & scripts usage
