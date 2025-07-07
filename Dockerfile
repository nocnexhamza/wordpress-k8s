# Use the official WordPress image with PHP and Apache
FROM wordpress:6.5-php8.2-apache

# Set environment variables for WordPress
ENV WORDPRESS_CONFIG_EXTRA=true \
    WORDPRESS_DB_HOST=wordpress-mysql \
    WORDPRESS_TABLE_PREFIX=wp_

# Install additional PHP extensions and tools
RUN apt-get update && apt-get install -y \
    less \
    nano \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) gd zip pdo_mysql opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure PHP for WordPress
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'upload_max_filesize=64M'; \
    echo 'post_max_size=64M'; \
    echo 'memory_limit=256M'; \
    echo 'max_execution_time=300'; \
} > /usr/local/etc/php/conf.d/wordpress-recommended.ini

# Configure Apache for Kubernetes
RUN { \
    echo '<Directory /var/www/html>'; \
    echo '  Options FollowSymLinks'; \
    echo '  AllowOverride All'; \
    echo '  Require all granted'; \
    echo '</Directory>'; \
    echo 'ErrorLog /dev/stderr'; \
    echo 'CustomLog /dev/stdout combined'; \
    echo 'ServerSignature Off'; \
    echo 'ServerTokens Prod'; \
} >> /etc/apache2/apache2.conf

# Add custom entrypoint for Kubernetes
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost/ || exit 1

# Set working directory and entrypoint
WORKDIR /var/www/html
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]