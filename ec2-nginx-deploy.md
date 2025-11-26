# Installing Nginx on Amazon EC2 from Source

## Problem Encountered

When following the tutorial to install nginx 1.19.0 from source, compilation failed with OpenSSL 3.0 deprecation errors:

```
error: 'ENGINE_by_id' is deprecated: Since OpenSSL 3.0
error: 'HMAC_Init_ex' is deprecated: Since OpenSSL 3.0
error: 'DH_free' is deprecated: Since OpenSSL 3.0
```

The issue: nginx 1.19.0 (released 2020) is incompatible with OpenSSL 3.0, which deprecated several APIs that older nginx versions still use.

## Solution: Install Newer Nginx Version

### Step 1: Download nginx 1.24.0

```bash
cd ~
wget http://nginx.org/download/nginx-1.24.0.tar.gz
tar -xzf nginx-1.24.0.tar.gz
cd nginx-1.24.0
```

### Step 2: Configure and Compile

```bash
./configure
make
sudo make install
```

### Step 3: Add nginx to PATH

```bash
echo 'export PATH=$PATH:/usr/local/nginx/sbin' >> ~/.bashrc
source ~/.bashrc
```

### Step 4: Verify Installation

```bash
nginx -v
# Output: nginx version: nginx/1.24.0
```

### Step 5: Start nginx

```bash
sudo nginx
```

### Step 6: Test nginx is Running

```bash
curl localhost
# Should return the default nginx welcome page HTML
```

## Useful nginx Commands

```bash
# Start nginx
sudo nginx

# Stop nginx
sudo nginx -s stop

# Reload configuration
sudo nginx -s reload

# Test configuration
sudo nginx -t

# Check if nginx is running
ps aux | grep nginx

# Check port 80 usage
sudo netstat -tlnp | grep :80
```

## Configuration Locations

- Config file: `/usr/local/nginx/conf/nginx.conf`
- Web root: `/usr/local/nginx/html/`
- Binary: `/usr/local/nginx/sbin/nginx`

## Alternative Installation Methods

### Option 1: Package Manager (Easiest)
```bash
sudo yum install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Option 2: Compile Old Version with Compatibility Flag
```bash
./configure --with-cc-opt="-Wno-error=deprecated-declarations"
make
sudo make install
```

## Key Takeaway

Always use nginx versions compatible with your system's OpenSSL version. For OpenSSL 3.0+, use nginx 1.22.0 or newer.
