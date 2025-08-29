#!/bin/bash
set -e

# Function to wait for MySQL
wait_for_mysql() {
    echo "Waiting for MySQL to be ready..."
    until mysql -h"${ESPOCRM_DATABASE_HOST}" -P"${ESPOCRM_DATABASE_PORT:-3306}" -u"${ESPOCRM_DATABASE_USER}" -p"${ESPOCRM_DATABASE_PASSWORD}" -e "SELECT 1" &> /dev/null; do
        echo "MySQL is not ready yet. Waiting..."
        sleep 2
    done
    echo "MySQL is ready!"
}

# Set default values
export ESPOCRM_DATABASE_HOST=${ESPOCRM_DATABASE_HOST:-mysql}
export ESPOCRM_DATABASE_PORT=${ESPOCRM_DATABASE_PORT:-3306}
export ESPOCRM_DATABASE_NAME=${ESPOCRM_DATABASE_NAME:-espocrm}
export ESPOCRM_DATABASE_USER=${ESPOCRM_DATABASE_USER:-espocrm}
export ESPOCRM_DATABASE_PASSWORD=${ESPOCRM_DATABASE_PASSWORD:-espocrm}
export ESPOCRM_ADMIN_USERNAME=${ESPOCRM_ADMIN_USERNAME:-admin}
export ESPOCRM_ADMIN_PASSWORD=${ESPOCRM_ADMIN_PASSWORD:-admin}
export ESPOCRM_SITE_URL=${ESPOCRM_SITE_URL:-http://localhost}

# Check if EspoCRM is already installed
if [ -f /var/www/html/data/config.php ]; then
    echo "EspoCRM is already configured."
else
    echo "First run detected. Configuring EspoCRM..."
    
    # Wait for database to be ready
    wait_for_mysql
    
    # Create config file
    cat > /var/www/html/data/config.php <<EOF
<?php
return [
    'database' => [
        'driver' => 'pdo_mysql',
        'host' => '${ESPOCRM_DATABASE_HOST}',
        'port' => '${ESPOCRM_DATABASE_PORT}',
        'dbname' => '${ESPOCRM_DATABASE_NAME}',
        'user' => '${ESPOCRM_DATABASE_USER}',
        'password' => '${ESPOCRM_DATABASE_PASSWORD}',
        'charset' => 'utf8mb4',
    ],
    'siteUrl' => '${ESPOCRM_SITE_URL}',
    'passwordSalt' => '$(openssl rand -hex 32)',
    'cryptKey' => '$(openssl rand -hex 16)',
    'hashSecretKey' => '$(openssl rand -hex 32)',
    'defaultPermissions' => [
        'user' => 33,
        'group' => 33,
    ],
    'logger' => [
        'path' => 'data/logs/espo.log',
        'level' => 'WARNING',
        'rotation' => true,
        'maxFileNumber' => 30,
    ],
    'applicationName' => 'EspoCRM',
    'version' => '8.0.0',
    'timeZone' => 'UTC',
    'dateFormat' => 'MM/DD/YYYY',
    'timeFormat' => 'HH:mm',
    'weekStart' => 1,
    'thousandSeparator' => ',',
    'decimalMark' => '.',
    'exportDelimiter' => ',',
    'language' => 'en_US',
    'useCache' => true,
    'recordsPerPage' => 20,
    'recordsPerPageSmall' => 10,
    'applicationName' => 'EspoCRM',
];
EOF
    
    # Set proper permissions
    chown www-data:www-data /var/www/html/data/config.php
    chmod 644 /var/www/html/data/config.php
    
    # Initialize database if needed
    if [ "${ESPOCRM_INIT_DATABASE}" = "true" ]; then
        echo "Initializing database..."
        php /var/www/html/rebuild.php
    fi
fi

# Ensure proper permissions
chown -R www-data:www-data /var/www/html/data
chown -R www-data:www-data /var/www/html/custom
chown -R www-data:www-data /var/www/html/upload

# Start cron service
service cron start

# Execute the main command
exec "$@"