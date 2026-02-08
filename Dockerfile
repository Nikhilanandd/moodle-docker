ARG PHP_VERSION=${PHP_VERSION:-8.3}
FROM php:${PHP_VERSION}-fpm-trixie

LABEL maintainer="Esdras Caleb / Custom Moodle 5.0.1"

ENV MOODLE_DIR="/var/www/moodle"
ENV MOODLE_DATA="/var/www/moodledata"
ENV DEBIAN_FRONTEND=noninteractive

# 1. System Dependencies and MS SQL Server
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg2 curl ca-certificates lsb-release nginx supervisor git jq \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev \
    libicu-dev libxml2-dev libpq-dev libonig-dev libxslt1-dev \
    libsodium-dev unixodbc-dev zlib1g-dev libssl-dev libmemcached-dev \
    graphviz aspell ghostscript poppler-utils \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg \
    && echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 \
    && rm -rf /var/lib/apt/lists/*

# 2. PHP Extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd intl zip soap opcache pdo pdo_pgsql pgsql mysqli pdo_mysql exif bcmath xsl sockets sodium \
    && pecl install redis sqlsrv pdo_sqlsrv memcached apcu \
    && docker-php-ext-enable redis sqlsrv pdo_sqlsrv memcached apcu

# 3. PHP-FPM Configuration - Use TCP socket
RUN { \
    echo '[global]'; \
    echo 'daemonize = no'; \
    echo '[www]'; \
    echo 'listen = 127.0.0.1:9000'; \
    echo 'listen.allowed_clients = 127.0.0.1'; \
    echo 'user = www-data'; \
    echo 'group = www-data'; \
    echo 'pm = dynamic'; \
    echo 'pm.max_children = 50'; \
    echo 'pm.start_servers = 5'; \
    echo 'pm.min_spare_servers = 5'; \
    echo 'pm.max_spare_servers = 35'; \
} > /usr/local/etc/php-fpm.d/www.conf

# 4. Nginx Configuration
RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
COPY nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Remove default nginx config that might conflict
RUN rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# 5. Moodle Structure
RUN mkdir -p $MOODLE_DATA /var/log/supervisor /var/log/nginx /var/cache/nginx /var/run /var/www/moodle

# 6. Copy Moodle Codebase
COPY ./moodle $MOODLE_DIR

# 7. Set Permissions (during build)
RUN chown -R www-data:www-data $MOODLE_DIR $MOODLE_DATA \
    && chmod -R 755 $MOODLE_DIR \
    && chmod -R 777 $MOODLE_DATA \
    && find $MOODLE_DIR -type f -exec chmod 644 {} \;

# 8. Copy Configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY php.ini /usr/local/etc/php/conf.d/99-moodle.ini

RUN chmod +x /usr/local/bin/entrypoint.sh

# Create required directories for runtime
RUN mkdir -p /var/www/moodle/localcache \
    && chmod 777 /var/www/moodle/localcache

EXPOSE 80
WORKDIR $MOODLE_DIR
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
