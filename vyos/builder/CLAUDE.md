# CLAUDE.md - VyOS ISO Builder

This project provides a streamlined environment for building VyOS ISO images from source code on a monthly or on-demand basis.

## Project Overview

This VyOS builder project creates a standardized workflow for:
- Building VyOS ISO images from the `current` branch (rolling release)
- Targeting `generic-amd64` architecture
- Managing build artifacts locally
- Providing simple script-based automation with future extensibility

## Project Structure

```
vyos/builder/
├── CLAUDE.md                    # This documentation file
├── README.md                    # Quick start guide  
├── .env.sample                  # Environment variables template
├── .gitignore                   # Git ignore patterns
├── scripts/
│   ├── build-iso.sh            # Main build script
│   ├── setup-environment.sh    # Initial setup script
│   ├── clean-build.sh          # Clean build artifacts
│   └── schedule-builds.sh      # Future: Cron/scheduling helper
├── config/
│   ├── build-config.yaml       # Build configuration settings
│   └── build-info.txt          # Build metadata tracking
├── output/                      # ISO build outputs (gitignored)
│   └── current/                # Latest build artifacts
├── logs/                        # Build logs (gitignored)
└── vyos-build/                  # VyOS source code (git submodule)
```

## Build Requirements

### System Requirements
- Debian Bookworm (12) or compatible Linux distribution
- Docker installed and current user in docker group
- Minimum 8GB RAM, 20GB free disk space
- Internet connection for downloading dependencies

### Dependencies
- Docker (for containerized builds)
- Git (for source code management)
- Basic shell utilities (bash, curl, etc.)

## Build Configuration

### Default Build Settings
- **Branch**: `current` (VyOS rolling release)
- **Architecture**: `amd64`
- **Build Type**: `generic` 
- **Container**: `vyos/vyos-build:current`
- **Output Format**: ISO image

### Customization Options
Build behavior can be modified via:
- `config/build-config.yaml` - Primary configuration
- Environment variables in `.env` file
- Command-line arguments to build scripts

## Common Commands

### Initial Setup
```bash
# Run initial environment setup
./scripts/setup-environment.sh

# Copy and customize environment variables
cp .env.sample .env
```

### Building VyOS ISO
```bash
# Build latest VyOS ISO
./scripts/build-iso.sh

# Build with custom build identifier
./scripts/build-iso.sh --build-by "your-email@domain.com"

# Build with verbose output
./scripts/build-iso.sh --verbose
```

### Maintenance
```bash
# Clean previous build artifacts
./scripts/clean-build.sh

# Clean everything including source
./scripts/clean-build.sh --full

# Update VyOS source to latest
cd vyos-build && git pull origin current
```

## Build Process Flow

1. **Environment Check**: Verify Docker, dependencies, and permissions
2. **Source Update**: Pull latest changes from VyOS `current` branch
3. **Container Setup**: Launch VyOS build container with proper mounts
4. **Dependency Install**: Install/update build dependencies in container
5. **ISO Generation**: Execute VyOS build process for `generic-amd64`
6. **Artifact Management**: Copy ISO to output directory with timestamp
7. **Logging**: Record build status, timing, and any errors
8. **Cleanup**: Remove temporary files and unused containers

## Build Output Structure

```
output/current/
├── vyos-1.5-rolling-YYYYMMDD-HHMMSS-amd64.iso    # Built ISO
├── vyos-1.5-rolling-YYYYMMDD-HHMMSS.md5sum       # Checksum file
└── build-info-YYYYMMDD-HHMMSS.txt                # Build metadata
```

## Logging and Monitoring

### Log Files
- `logs/build-YYYYMMDD-HHMMSS.log` - Detailed build logs
- `logs/error-YYYYMMDD-HHMMSS.log` - Error-specific logs
- `logs/build-summary.log` - Build success/failure summary

### Build Status Tracking
Each build generates metadata including:
- Build timestamp and duration
- VyOS source commit hash
- Build container version
- Success/failure status
- ISO file size and checksums

## Troubleshooting

### Common Issues

**Docker Permission Errors**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again
```

**Build Container Access**
```bash
# Pull latest build container
docker pull vyos/vyos-build:current

# Check Docker daemon status
sudo systemctl status docker
```

**Disk Space Issues**
```bash
# Clean Docker containers and images
docker system prune -a

# Clean build artifacts
./scripts/clean-build.sh --full
```

**Source Code Issues**
```bash
# Reset VyOS source to clean state
cd vyos-build
git clean -fdx
git reset --hard origin/current
```

## Security Considerations

### Build Environment
- Build process runs in isolated Docker container
- No privileged access required for basic operations
- Source code pulled from official VyOS repository only

### Output Security
- Generated ISOs should be verified with provided checksums
- Store build artifacts in secure location if needed
- Consider signing ISOs for production use

## Future Enhancements

### Planned Features
- Automated scheduling via cron
- Build notifications (email, webhooks)
- Multi-architecture support
- Custom package integration
- Build artifact archiving
- CI/CD pipeline integration

### Extension Points
- Custom package directory (`packages/custom/`)
- Pre/post-build hook scripts
- Alternative build targets
- Remote artifact storage
- Build result APIs

## Development Workflow

### Adding Custom Packages
1. Place `.deb` files in `vyos-build/packages/` directory
2. Packages will be automatically included in next build
3. Document custom packages in `config/build-info.txt`

### Modifying Build Configuration
1. Edit `config/build-config.yaml` for permanent changes
2. Use environment variables for temporary overrides
3. Test changes with non-production builds first

### Contributing Improvements
1. Test changes in isolated environment
2. Update documentation for new features
3. Maintain backward compatibility where possible
4. Follow existing code style and patterns

## Resource Management

### Disk Usage
- VyOS source: ~2GB
- Build container: ~4GB
- Single ISO build: ~500MB
- Build logs: ~50MB per build

### Performance Tuning
- Allocate 8GB+ RAM for faster builds
- Use SSD storage for better I/O performance
- Consider Docker resource limits for shared systems
- Clean old artifacts regularly to manage disk usage

This builder provides a foundation for reliable VyOS ISO generation with room for future automation and enhancement.