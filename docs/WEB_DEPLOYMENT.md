# StripCall Web App Local Deployment

This directory contains scripts to deploy the StripCall web app locally for testing alongside mobile development.

## Scripts

### `deploy_web_local.sh`
Builds and deploys the Flutter web app locally on port 3000.

**Usage:**
```bash
./deploy_web_local.sh
```

**What it does:**
1. Cleans previous builds
2. Gets dependencies
3. Builds the web app in release mode
4. Copies build files to `deploy/web/`
5. Starts a Python HTTP server on port 3000
6. Opens the app at `http://localhost:3000`

**Features:**
- ✅ Colored output for easy reading
- ✅ Error handling and validation
- ✅ Automatic cleanup on exit (Ctrl+C)
- ✅ Kills existing processes on the same port
- ✅ Includes all necessary environment variables

### `stop_web_server.sh`
Stops the local web server.

**Usage:**
```bash
./stop_web_server.sh
```

## Workflow

### For Web Testing:
```bash
./deploy_web_local.sh
```
Then open `http://localhost:3000` in your browser.

### For Mobile Development:
```bash
flutter run -d <device_id>
```

### Running Both Simultaneously:
1. Start the web server: `./deploy_web_local.sh`
2. In another terminal, run mobile: `flutter run -d <device_id>`
3. Test both versions simultaneously

## Configuration

- **Web Port**: 3000 (configurable in `deploy_web_local.sh`)
- **Build Directory**: `build/web/`
- **Deploy Directory**: `deploy/web/`
- **Environment**: Release mode with production settings

## Requirements

- Flutter SDK
- Python 3 (for HTTP server)
- macOS/Linux (scripts use bash)

## Troubleshooting

### Port Already in Use
If port 3000 is already in use, the script will automatically kill existing processes.

### Build Failures
Check that you're in the Flutter project root directory and that all dependencies are installed.

### Server Won't Start
Make sure Python is installed and accessible in your PATH.

## Notes

- The web app runs in release mode for better performance
- All environment variables are included in the build
- The server automatically stops when you press Ctrl+C
- Build files are copied to a separate deploy directory for clean separation 