# StripCall Web App Deployment to Hostinger

This guide explains how to deploy your Flutter web app to Hostinger hosting with automated scripts.

## Prerequisites

1. **Hostinger Account**: You need a Hostinger hosting account with FTP access
2. **Domain**: Your domain `stripcall.us` should be configured in Hostinger
3. **FTP Credentials**: Get your FTP host, username, and password from Hostinger

## Setup Instructions

### 1. Get Your Hostinger FTP Credentials

1. Log into your Hostinger control panel
2. Go to **Files** → **FTP Accounts**
3. Note down:
   - **FTP Host** (usually `your-domain.com` or `your-server.hostinger.com`)
   - **FTP Username**
   - **FTP Password**
   - **FTP Port** (usually 21)

### 2. Configure Deployment Scripts

1. **Copy the configuration template**:
   ```bash
   cp scripts/hostinger_config.sh scripts/hostinger_config_local.sh
   ```

2. **Edit the configuration file** with your actual credentials:
   ```bash
   nano hostinger_config_local.sh
   ```

3. **Update the values**:
   ```bash
   export HOSTINGER_FTP_HOST="your-actual-ftp-host.hostinger.com"
   export HOSTINGER_FTP_USER="your-actual-ftp-username"
   export HOSTINGER_FTP_PASS="your-actual-ftp-password"
   export HOSTINGER_FTP_PATH="/public_html"
   export HOSTINGER_DOMAIN="stripcall.us"
   ```

### 3. Install Required Tools

#### Option A: Using lftp (Recommended)
```bash
# macOS
brew install lftp

# Ubuntu/Debian
sudo apt-get install lftp

# CentOS/RHEL
sudo yum install lftp
```

#### Option B: Using rsync
```bash
# macOS
brew install rsync

# Ubuntu/Debian
sudo apt-get install rsync

# CentOS/RHEL
sudo yum install rsync
```

## Deployment Scripts

### Option 1: lftp Deployment (Recommended)

**Script**: `deploy_to_hostinger.sh`

**Usage**:
```bash
./scripts/deploy_to_hostinger.sh
```

**What it does**:
1. Builds the Flutter web app in release mode
2. Prepares deployment files with proper .htaccess configuration
3. Uploads files to Hostinger via FTP
4. Configures HTTPS and security headers

### Option 2: rsync Deployment

**Script**: `deploy_to_hostinger_rsync.sh`

**Usage**:
```bash
./deploy_to_hostinger_rsync.sh
```

**What it does**:
1. Same as lftp but uses rsync for file transfer
2. Generally faster for large deployments
3. Better for incremental updates

## Deployment Process

### 1. Build and Deploy
```bash
# Make sure you're in the project root
cd /path/to/stripcall

# Run the deployment script
./scripts/deploy_to_hostinger.sh
```

### 2. What Gets Deployed

The script will:
- ✅ Build the Flutter web app in release mode
- ✅ Include all environment variables (Supabase, Firebase)
- ✅ Create proper .htaccess for SPA routing
- ✅ Add security headers
- ✅ Configure caching for static assets
- ✅ Enable Gzip compression
- ✅ Upload to your Hostinger public_html directory

### 3. Post-Deployment

After deployment:
1. **Wait 2-5 minutes** for DNS propagation
2. **Visit https://stripcall.us** to verify the deployment
3. **Test all features** including:
   - User authentication
   - FCM notifications
   - Crew management
   - Problem reporting

## HTTPS Configuration

The deployment scripts automatically configure:
- ✅ HTTPS redirects
- ✅ Security headers
- ✅ Content Security Policy
- ✅ XSS protection
- ✅ Frame protection

## Troubleshooting

### Common Issues

#### 1. FTP Connection Failed
```
Error: Could not connect to FTP server
```
**Solution**: 
- Verify FTP credentials in `hostinger_config_local.sh`
- Check if FTP is enabled in Hostinger control panel
- Try connecting with an FTP client first

#### 2. Build Failed
```
Error: Build failed - build/web not found
```
**Solution**:
- Run `flutter doctor` to check Flutter installation
- Run `flutter clean && flutter pub get` manually
- Check for any compilation errors

#### 3. App Not Loading
```
Error: App shows blank page or 404
```
**Solution**:
- Check if .htaccess file was uploaded correctly
- Verify all files are in the public_html directory
- Check browser console for JavaScript errors

#### 4. FCM Not Working
```
Error: FCM notifications not working on production
```
**Solution**:
- Verify Firebase configuration is correct
- Check if VAPID key is properly set
- Ensure HTTPS is working (FCM requires HTTPS)

### Debug Commands

```bash
# Test FTP connection
lftp -u username,password ftp.hostinger.com

# Check build output
ls -la build/web/

# Verify deployment files
ls -la deploy/hostinger/

# Test local build
flutter build web --release
```

## Security Considerations

### 1. Credentials Security
- ✅ `hostinger_config_local.sh` is in .gitignore
- ✅ Never commit credentials to version control
- ✅ Use environment variables when possible

### 2. HTTPS Enforcement
- ✅ All traffic redirected to HTTPS
- ✅ Security headers configured
- ✅ CSP headers set

### 3. File Permissions
- ✅ Web files: 644
- ✅ Directories: 755
- ✅ .htaccess: 644

## Performance Optimization

The deployment includes:
- ✅ Gzip compression for all text files
- ✅ Long-term caching for static assets
- ✅ Optimized Flutter web build
- ✅ CanvasKit renderer for better performance

## Monitoring

### 1. Check Deployment Status
```bash
# View deployment logs
tail -f deploy.log

# Check file upload status
ls -la deploy/hostinger/
```

### 2. Monitor Website
- Use Hostinger's built-in monitoring
- Set up uptime monitoring (e.g., UptimeRobot)
- Monitor error logs in Hostinger control panel

## Backup Strategy

### 1. Automatic Backups
The deployment script can create backups:
```bash
export HOSTINGER_BACKUP_ENABLED="true"
export HOSTINGER_BACKUP_DIR="./backups"
```

### 2. Manual Backups
```bash
# Download current version
lftp -u username,password ftp.hostinger.com -e "mirror public_html backups/$(date +%Y%m%d_%H%M%S)"
```

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Hostinger's documentation
3. Check Flutter web deployment guides
4. Contact Hostinger support for hosting-specific issues

## Next Steps

After successful deployment:
1. Set up monitoring and alerts
2. Configure automated backups
3. Set up CI/CD pipeline (optional)
4. Monitor performance and user feedback 