# Multi-stage build for EspoCRM
FROM php:8.1-apache AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libldap2-dev \
    libicu-dev \
    libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    zip \
    gd \
    mbstring \
    xml \
    bcmath \
    soap \
    intl \
    ldap \
    opcache \
    exif

# Install ImageMagick
RUN pecl install imagick && docker-php-ext-enable imagick

# Production image
FROM php:8.1-apache

# Install runtime dependencies - let apt resolve versions
RUN apt-get update && apt-get install -y \
    curl \
    cron \
    supervisor \
    imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Enable Apache modules
RUN a2enmod rewrite headers expires deflate

# Configure Apache to run on port 8080 (non-privileged)
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/g' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/g' /etc/apache2/sites-available/default-ssl.conf

# Configure Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Set up Apache configuration for EspoCRM
COPY --chown=www-data:www-data apache-espocrm.conf /etc/apache2/sites-available/000-default.conf

# Copy EspoCRM application files
COPY --chown=www-data:www-data . /var/www/html

# Create required directories first
RUN mkdir -p /var/www/html/data \
    && mkdir -p /var/www/html/custom \
    && mkdir -p /var/www/html/upload \
    && mkdir -p /var/www/html/application/Espo/Modules \
    && mkdir -p /var/www/html/client/custom

# Set proper permissions
RUN find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && chmod 775 /var/www/html/data \
    && chmod 775 /var/www/html/custom \
    && chmod 775 /var/www/html/upload \
    && chmod 775 /var/www/html/application/Espo/Modules \
    && chmod 775 /var/www/html/client/custom

# Create required directories
RUN mkdir -p /var/www/html/data/logs \
    && mkdir -p /var/www/html/data/cache \
    && mkdir -p /var/www/html/data/upload \
    && chown -R www-data:www-data /var/www/html/data

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/conf.d/espocrm.ini

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set up cron for EspoCRM
RUN echo "* * * * * www-data cd /var/www/html && php cron.php > /dev/null 2>&1" > /etc/cron.d/espocrm \
    && chmod 0644 /etc/cron.d/espocrm \
    && crontab /etc/cron.d/espocrm

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/App/health || exit 1

# Expose port 8080 (non-privileged)
EXPOSE 8080

# Set working directory
WORKDIR /var/www/html

# Use custom entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]