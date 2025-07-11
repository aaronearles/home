# VyOS ISO Builder

A streamlined environment for building VyOS ISO images from source code.

## Quick Start

1. **Initial Setup**
   ```bash
   ./scripts/setup-environment.sh
   ```

2. **Configure Build Settings**
   ```bash
   cp .env.sample .env
   # Edit .env file with your preferences
   ```

3. **Build VyOS ISO**
   ```bash
   ./scripts/build-iso.sh
   ```

## Features

- **Simple Scripts**: Easy-to-use build automation
- **Docker-based**: Isolated build environment
- **Configurable**: Customizable build settings
- **Logging**: Comprehensive build logs
- **Future-ready**: Extensible for automation

## Requirements

- Debian Bookworm (12) or compatible
- Docker installed and configured
- Git for source code management
- 8GB+ RAM, 20GB+ free disk space

## Build Configuration

Default settings:
- **Branch**: `current` (VyOS rolling release)
- **Architecture**: `amd64`
- **Type**: `generic`
- **Storage**: Local output directory

## Scripts

- `setup-environment.sh` - Initial environment setup
- `build-iso.sh` - Main build script
- `clean-build.sh` - Clean artifacts and logs
- `schedule-builds.sh` - Future: Automated scheduling

## Documentation

See `CLAUDE.md` for comprehensive documentation including:
- Detailed build process
- Configuration options
- Troubleshooting guide
- Future enhancement plans

## Support

For issues or questions, refer to:
- VyOS documentation: https://docs.vyos.io
- VyOS build repository: https://github.com/vyos/vyos-build
- Project documentation: `CLAUDE.md`