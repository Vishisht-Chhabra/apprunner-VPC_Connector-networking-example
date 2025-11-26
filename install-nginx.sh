#!/bin/bash

# Nginx Installation Script for Amazon EC2
# This script installs nginx from source with OpenSSL 3.0 compatibility

set -e  # Exit on any error

NGINX_VERSION="1.24.0"
INSTALL_DIR="/usr/local/nginx"
DOWNLOAD_DIR="$HOME"

echo "=========================================="
echo "Nginx Installation Script"
echo "Version: $NGINX_VERSION"
echo "=========================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo or as root"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
yum install -y gcc pcre-devel zlib-devel openssl-devel make wget

# Download nginx
echo "Downloading nginx $NGINX_VERSION..."
cd "$DOWNLOAD_DIR"
wget -q http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz

# Extract
echo "Extracting nginx..."
tar -xzf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION

# Configure
echo "Configuring nginx..."
./configure \
    --prefix=$INSTALL_DIR \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_gzip_static_module

# Compile
echo "Compiling nginx (this may take a few minutes)..."
make

# Install
echo "Installing nginx..."
make install

# Add to PATH for all users
echo "Configuring PATH..."
if ! grep -q "$INSTALL_DIR/sbin" /etc/profile; then
    echo "export PATH=\$PATH:$INSTALL_DIR/sbin" >> /etc/profile
fi

# Create symlink
echo "Creating symlink..."
ln -sf $INSTALL_DIR/sbin/nginx /usr/bin/nginx

# Verify installation
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
nginx -v

# Check if nginx is already running
if pgrep nginx > /dev/null; then
    echo "Nginx is already running"
else
    echo ""
    read -p "Do you want to start nginx now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nginx
        echo "Nginx started successfully!"
        echo "Test with: curl localhost"
    fi
fi

echo ""
echo "Configuration file: $INSTALL_DIR/conf/nginx.conf"
echo "Web root: $INSTALL_DIR/html/"
echo ""
echo "Useful commands:"
echo "  Start:   sudo nginx"
echo "  Stop:    sudo nginx -s stop"
echo "  Reload:  sudo nginx -s reload"
echo "  Test:    sudo nginx -t"
