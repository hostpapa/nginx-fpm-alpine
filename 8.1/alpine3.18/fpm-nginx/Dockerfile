#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM php:8.1.1-fpm-alpine3.18

# Persistent dependencies
RUN set -eux; \
    apk add --no-cache \
# Ghostscript is required for rendering PDF previews
        ghostscript \
        tzdata \
        curl \
        ca-certificates \
        supervisor \
    ; \
### Setup needed PHP dependencies ###
# Install the PHP extensions we need (https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions)
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        imagemagick-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        php81-pecl-ast \
        icu-dev \
    ; \
    pecl install ast imagick; \
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
    docker-php-ext-enable opcache imagick ast; \
    rm -r /tmp/pear; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-network --virtual .wordpress-phpexts-rundeps $runDeps; \
    apk del --no-network .build-deps \
    ; \
### Install Nginx and other dependencies ###
# create nginx user/group first, to be consistent throughout docker variants
    addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apk add --no-cache \
        nginx \
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
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    ; \
# Required fcgi for php-fpm-healthcheck
    apk add --no-cache fcgi \
# Assign Host User
    shadow \
    && usermod -u 1000 www-data \
    && groupmod -g 1000 www-data

# Copy the healthcheck
COPY ./healthcheck/php-fpm-healthcheck /usr/local/bin/

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
