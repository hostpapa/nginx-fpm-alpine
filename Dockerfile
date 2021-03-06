##
# __        __   _       ___
# \ \      / /__| |__   |_ _|_ __ ___   __ _  __ _  ___
#  \ \ /\ / / _ \ '_ \   | || '_ ` _ \ / _` |/ _` |/ _ \
#   \ V  V /  __/ |_) |  | || | | | | | (_| | (_| |  __/
#    \_/\_/ \___|_.__/  |___|_| |_| |_|\__,_|\__, |\___|
#                                            |___/
#
# This is the base _Web Image_ which combines FPM and Nginx into a single
# image, starting them up at the end with Supervisord. By having a single
# container, we can simplify deployments. For example, in Kubernetes, we don't
# have to worry about shared volumes and init containers.
#
# The Nginx setup within this container is setup to ONLY listen on Port 80
# (non-ssl) with the expectation that SSL is terminated at a load balancer and
# then proxied to this container. This allows this container to be simpler and
# leave SSL creation and termination to the deployment environment. Even in a
# Kubernetes setup, a Service Mesh SHOULD be used to enforce mTLS encrypting
# all internal traffic. Even in this scenario, we _still_ only need a container
# that listed on Port 80.
#
# This image _starts off_ with the official PHP FPM image as, between Nginx and
# FPM, FPM is more complex to setup. The best of both Nginx and FPM containers
# have been combined into this image from a functionality perspective (nginx
# templates with envsubst, etc).
##
FROM php:8.0-fpm-alpine

# Persistent dependencies
RUN set -eux; \
    apk add --no-cache \
# Ghostscript is required for rendering PDF previews
        ghostscript \
# Alpine package for "imagemagick" contains ~120 .so files, see: https://github.com/docker-library/wordpress/pull/497
        # imagemagick \
        tzdata \
        curl \
        ca-certificates \
        supervisor \
    ;

### Setup needed PHP dependencies ###
# Install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        # imagemagick-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        php8-pecl-ast \
        icu-dev \
    ; \
    \
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    ; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        gd \
        mysqli \
        zip \
        intl \
    ; \
    docker-php-ext-enable opcache; \
    # pecl install ast; \
    # docker-php-ext-enable ast; \
# WARNING: imagick is likely not supported on Alpine: https://github.com/Imagick/imagick/issues/328
# https://pecl.php.net/package/imagick
    # pecl install imagick-3.5.0; \
    # docker-php-ext-enable imagick; \
# Remove temp PECL folder
    # rm -r /tmp/pear; \
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-network --virtual .wordpress-phpexts-rundeps $runDeps; \
    apk del --no-network .build-deps


### Install Nginx and other dependencies ###
RUN set -eux \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apk add --no-cache \
        nginx \
# Move http.d to conf.d to match other Nginx setups and scripts
    && mv /etc/nginx/http.d /etc/nginx/conf.d \
# Replace references to http.d with conf.d in main Nginx config installed by default
# This allows this image to function on its own even though most will override nginx.conf entirely
    && sed -i 's/http.d/conf.d/g' /etc/nginx/nginx.conf \
    \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
    scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | sort -u \
    | xargs -r apk info --installed \
    | sort -u \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps \
    # && apk del .build-deps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    \
# Make the entrypoint scripts folder
    && mkdir /docker-entrypoint.d \
    \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Copy scripts into entrypoints folder and set script
COPY ./docker-entrypoint.sh /
COPY ./entrypoints/* /docker-entrypoint.d/
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]

# Copy in Composer 2
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Add Composer bin to PATH
ENV PATH=/root/.composer/vendor/bin:$PATH \
    COMPOSER_HOME=/root/.composer

# Copy in supervisor configs and start script
COPY ./supervisord.conf /etc/supervisord.conf

# Set the port to listen on. Normally this would be 80, but deployment
# topologies like Heroku can change and override the port to listen on.
ARG PORT=80
ENV PORT=$PORT
EXPOSE $PORT

# Expose the main folder as a volume for use by other containers where needed
VOLUME ["/var/www/html"]

# Copy in and use the server start script
COPY ./start-server.sh /
CMD ["/bin/sh", "/start-server.sh"]
