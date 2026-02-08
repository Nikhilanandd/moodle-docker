#!/bin/bash
set -e

echo "=============================================="
echo "  Moodle 5.0.1 + PHP 8.3 Container Starting"
echo "=============================================="

# Ensure directories exist
mkdir -p $MOODLE_DATA /var/log/supervisor /var/log/nginx /var/cache/nginx /var/run

# Set permissions (with error suppression for read-only files)
chown -R www-data:www-data $MOODLE_DATA 2>/dev/null || true
chmod 777 $MOODLE_DATA 2>/dev/null || true

# Ensure localcache exists and is writable
mkdir -p $MOODLE_DIR/localcache
chmod 777 $MOODLE_DIR/localcache 2>/dev/null || true

# Check config.php
if [ -f "$MOODLE_DIR/config.php" ]; then
    echo "✓ config.php found"
else
    echo "✗ WARNING: config.php NOT found at $MOODLE_DIR/config.php"
    echo "  Moodle will show installation page"
fi

# Test PHP
echo "✓ PHP Version: $(php -r 'echo PHP_VERSION;')"

# Verify extensions
echo "✓ Checking required extensions..."
for ext in gd mysqli pgsql redis apcu; do
    php -m | grep -q "^$ext$" && echo "  ✓ $ext" || echo "  ✗ $ext MISSING"
done

# Test Nginx config
if nginx -t 2>/dev/null; then
    echo "✓ Nginx configuration OK"
else
    echo "✗ Nginx configuration FAILED"
    nginx -t
fi

# Test PHP-FPM
if php-fpm -t 2>/dev/null; then
    echo "✓ PHP-FPM configuration OK"
else
    echo "✗ PHP-FPM configuration FAILED"
    php-fpm -t
fi

echo "=============================================="
echo "  Starting Services..."
echo "=============================================="

exec "$@"
