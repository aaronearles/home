#!/bin/bash
# build-iso.sh - Main VyOS ISO Build Script
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables if .env exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Default values
BUILD_BY="${BUILD_BY:-builder@localhost}"
BUILD_ARCHITECTURE="${BUILD_ARCHITECTURE:-amd64}"
BUILD_TYPE="${BUILD_TYPE:-generic}"
BUILD_BRANCH="${BUILD_BRANCH:-current}"
VYOS_BUILD_CONTAINER="${VYOS_BUILD_CONTAINER:-vyos/vyos-build:current}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/output/current}"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
VERBOSE_BUILD="${VERBOSE_BUILD:-false}"
CLEAN_BEFORE_BUILD="${CLEAN_BEFORE_BUILD:-false}"
UPDATE_SOURCE="${UPDATE_SOURCE:-true}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build-by)
            BUILD_BY="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE_BUILD="true"
            shift
            ;;
        --clean)
            CLEAN_BEFORE_BUILD="true"
            shift
            ;;
        --no-update)
            UPDATE_SOURCE="false"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --build-by EMAIL    Set build identifier email"
            echo "  --verbose           Enable verbose output"
            echo "  --clean             Clean before building"
            echo "  --no-update         Skip source code update"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Generate timestamp for this build
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BUILD_LOG="$LOG_DIR/build-$TIMESTAMP.log"
ERROR_LOG="$LOG_DIR/error-$TIMESTAMP.log"

# Global variables
start_time=0

# Ensure directories exist
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# Enhanced logging functions
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$message"
    # Create log file if it doesn't exist and append
    mkdir -p "$(dirname "$BUILD_LOG")" 2>/dev/null || true
    echo "$message" >> "$BUILD_LOG" 2>/dev/null || true
}

error_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*"
    echo "$message"
    mkdir -p "$(dirname "$BUILD_LOG")" 2>/dev/null || true
    echo "$message" >> "$BUILD_LOG" 2>/dev/null || true
    echo "$message" >> "$ERROR_LOG" 2>/dev/null || true
}

warn_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*"
    echo "$message"
    mkdir -p "$(dirname "$BUILD_LOG")" 2>/dev/null || true
    echo "$message" >> "$BUILD_LOG" 2>/dev/null || true
}

info_log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"
    echo "$message"
    mkdir -p "$(dirname "$BUILD_LOG")" 2>/dev/null || true
    echo "$message" >> "$BUILD_LOG" 2>/dev/null || true
}

# Progress logging for long operations
progress_log() {
    local message="$1"
    local current="$2"
    local total="$3"
    local percent=$((current * 100 / total))
    local log_msg="[$(date '+%Y-%m-%d %H:%M:%S')] PROGRESS: $message [$current/$total] ($percent%)"
    echo "$log_msg"
    mkdir -p "$(dirname "$BUILD_LOG")" 2>/dev/null || true
    echo "$log_msg" >> "$BUILD_LOG" 2>/dev/null || true
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    if ! command -v docker >/dev/null 2>&1; then
        error_log "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        error_log "Cannot access Docker. Check if Docker is running and user has permissions"
        exit 1
    fi
    
    if [[ ! -d "$PROJECT_ROOT/vyos-build" ]]; then
        error_log "VyOS source directory not found. Run setup-environment.sh first"
        exit 1
    fi
    
    log "✅ Prerequisites check passed"
}

# Update VyOS source code
update_source() {
    if [[ "$UPDATE_SOURCE" == "true" ]]; then
        log "📥 Updating VyOS source code..."
        cd "$PROJECT_ROOT/vyos-build" || return 1
        git fetch origin || return 1
        git checkout $BUILD_BRANCH 2>/dev/null || true
        git reset --hard origin/$BUILD_BRANCH || return 1
        log "✅ Source code updated to latest $BUILD_BRANCH"
    else
        log "⏭️  Skipping source code update"
    fi
    return 0
}

# Clean build artifacts
clean_build() {
    if [[ "$CLEAN_BEFORE_BUILD" == "true" ]]; then
        log "🧹 Cleaning previous build artifacts..."
        cd "$PROJECT_ROOT/vyos-build" || return 1
        if [[ -d "build" ]]; then
            sudo rm -rf build/ || return 1
        fi
        log "✅ Build artifacts cleaned"
    fi
    return 0
}

# Pull latest build container
pull_container() {
    log "🐳 Pulling latest build container..."
    if docker pull "$VYOS_BUILD_CONTAINER"; then
        log "✅ Container updated"
        return 0
    else
        error_log "Failed to pull container"
        return 1
    fi
}

# Enhanced build function with better error handling
build_iso() {
    log "🚀 Starting VyOS ISO build..."
    log "   Branch: $BUILD_BRANCH"
    log "   Architecture: $BUILD_ARCHITECTURE"
    log "   Type: $BUILD_TYPE"
    log "   Builder: $BUILD_BY"
    log "   Container: $VYOS_BUILD_CONTAINER"
    
    # Validate build directory
    if [[ ! -d "$PROJECT_ROOT/vyos-build" ]]; then
        error_log "VyOS build directory not found: $PROJECT_ROOT/vyos-build"
        return 1
    fi
    
    cd "$PROJECT_ROOT/vyos-build" || {
        error_log "Failed to change to VyOS build directory"
        return 1
    }
    
    # Verify build script exists
    if [[ ! -f "build-vyos-image" ]]; then
        error_log "VyOS build script not found: build-vyos-image"
        return 1
    fi
    
    # Prepare build command
    local verbose_flag=""
    if [[ "$VERBOSE_BUILD" == "true" ]]; then
        verbose_flag="--debug"
    fi
    
    # Check available disk space (need at least 10GB)
    local available_space
    available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        warn_log "Low disk space: $(($available_space/1024/1024))GB available, 10GB+ recommended"
    fi
    
    # Execute build in container with enhanced error handling
    local build_cmd="cd /vyos && sudo make clean && sudo ./build-vyos-image --architecture $BUILD_ARCHITECTURE --build-by '$BUILD_BY' $verbose_flag $BUILD_TYPE"
    
    log "🔨 Executing build command in container..."
    info_log "Build command: $build_cmd"
    info_log "Expected build time: 30-60 minutes"
    info_log "Monitor progress: tail -f $BUILD_LOG"
    
    # Run build with timeout and proper error capture
    local build_start_time
    build_start_time=$(date +%s)
    
    # Ensure build output directory exists
    mkdir -p "$(pwd)/build"
    
    # Use Docker container but run debootstrap on host to bypass permission issues
    if timeout 7200 docker run --rm \
        --privileged \
        --pid=host \
        --network=host \
        -v /dev:/dev \
        -v /proc:/proc \
        -v /sys:/sys \
        -v "$(pwd)":/vyos \
        -w /vyos \
        "$VYOS_BUILD_CONTAINER" \
        bash -c "$build_cmd" 2>&1 | tee -a "$BUILD_LOG"; then
        
        local build_end_time
        build_end_time=$(date +%s)
        local build_duration=$((build_end_time - build_start_time))
        
        log "✅ Build completed successfully in ${build_duration}s"
        info_log "Build artifacts should be in: $(pwd)/build/"
        return 0
    else
        local exit_code=$?
        local build_end_time
        build_end_time=$(date +%s)
        local build_duration=$((build_end_time - build_start_time))
        
        if [[ $exit_code -eq 124 ]]; then
            error_log "Build timed out after 2 hours (${build_duration}s)"
        else
            error_log "Build failed with exit code $exit_code after ${build_duration}s"
        fi
        
        # Capture any Docker or system errors
        if ! docker info >/dev/null 2>&1; then
            error_log "Docker daemon appears to be unavailable"
        fi
        
        return 1
    fi
}

# Enhanced artifact management
copy_artifacts() {
    log "📦 Copying build artifacts..."
    
    # Validate build directory exists
    if [[ ! -d "$PROJECT_ROOT/vyos-build/build" ]]; then
        error_log "Build directory not found: $PROJECT_ROOT/vyos-build/build"
        return 1
    fi
    
    cd "$PROJECT_ROOT/vyos-build/build" || {
        error_log "Failed to change to build directory"
        return 1
    }
    
    # Find all generated artifacts
    local iso_files
    mapfile -t iso_files < <(find . -name "*.iso" -type f)
    
    if [[ ${#iso_files[@]} -eq 0 ]]; then
        error_log "No ISO files found in build directory"
        info_log "Build directory contents:"
        ls -la . | tee -a "$BUILD_LOG"
        return 1
    fi
    
    if [[ ${#iso_files[@]} -gt 1 ]]; then
        warn_log "Multiple ISO files found, using the first one:"
        printf '%s\n' "${iso_files[@]}" | tee -a "$BUILD_LOG"
    fi
    
    local iso_file="${iso_files[0]}"
    info_log "Selected ISO file: $iso_file"
    
    # Validate ISO file
    if [[ ! -r "$iso_file" ]]; then
        error_log "Cannot read ISO file: $iso_file"
        return 1
    fi
    
    local iso_size
    iso_size=$(stat -c%s "$iso_file" 2>/dev/null || echo "0")
    if [[ $iso_size -lt 100000000 ]]; then  # Less than 100MB is suspicious
        warn_log "ISO file seems small: $(du -h "$iso_file" | cut -f1) - build may have failed"
    fi
    
    # Generate new filename with timestamp
    local iso_basename
    iso_basename=$(basename "$iso_file")
    local new_iso_name="${iso_basename%.iso}-$TIMESTAMP.iso"
    
    # Copy ISO with verification
    log "Copying ISO: $iso_file -> $OUTPUT_DIR/$new_iso_name"
    if ! cp "$iso_file" "$OUTPUT_DIR/$new_iso_name"; then
        error_log "Failed to copy ISO file"
        return 1
    fi
    
    # Verify copy
    local original_size copied_size
    original_size=$(stat -c%s "$iso_file")
    copied_size=$(stat -c%s "$OUTPUT_DIR/$new_iso_name")
    
    if [[ $original_size -ne $copied_size ]]; then
        error_log "ISO copy verification failed: size mismatch"
        return 1
    fi
    
    # Generate checksums
    cd "$OUTPUT_DIR" || {
        error_log "Failed to change to output directory"
        return 1
    }
    
    log "Generating checksums..."
    md5sum "$new_iso_name" > "${new_iso_name%.iso}.md5sum"
    sha256sum "$new_iso_name" > "${new_iso_name%.iso}.sha256sum"
    
    # Create detailed build info file
    cat > "build-info-$TIMESTAMP.txt" << EOF
VyOS Build Information
=======================
Build Timestamp: $(date)
Build Duration: $(($(date +%s) - start_time)) seconds

Source Information:
  Branch: $BUILD_BRANCH
  Commit: $(cd "$PROJECT_ROOT/vyos-build" && git rev-parse HEAD)
  Commit Date: $(cd "$PROJECT_ROOT/vyos-build" && git show -s --format=%ci HEAD)
  Remote URL: $(cd "$PROJECT_ROOT/vyos-build" && git remote get-url origin)

Build Configuration:
  Architecture: $BUILD_ARCHITECTURE
  Build Type: $BUILD_TYPE
  Builder: $BUILD_BY
  Container: $VYOS_BUILD_CONTAINER
  Verbose: $VERBOSE_BUILD

Output Information:
  ISO File: $new_iso_name
  ISO Size: $(du -h "$new_iso_name" | cut -f1)
  MD5: $(cat "${new_iso_name%.iso}.md5sum" | cut -d' ' -f1)
  SHA256: $(cat "${new_iso_name%.iso}.sha256sum" | cut -d' ' -f1)

System Information:
  Build Host: $(hostname)
  Build User: $(whoami)
  Build Directory: $(pwd)
  Available Space: $(df -h . | awk 'NR==2 {print $4}')
  Docker Version: $(docker --version)
EOF
    
    log "✅ Artifacts copied to $OUTPUT_DIR"
    log "   ISO: $new_iso_name"
    log "   Size: $(du -h "$new_iso_name" | cut -f1)"
    log "   MD5: $(cat "${new_iso_name%.iso}.md5sum" | cut -d' ' -f1)"
    info_log "Build info saved to: build-info-$TIMESTAMP.txt"
}

# Enhanced cleanup function
cleanup() {
    local cleanup_start_time
    cleanup_start_time=$(date +%s)
    
    log "🧹 Performing cleanup..."
    
    # Stop any running VyOS build containers
    local running_containers
    running_containers=$(docker ps -q --filter "ancestor=$VYOS_BUILD_CONTAINER" 2>/dev/null || true)
    if [[ -n "$running_containers" ]]; then
        warn_log "Stopping running VyOS build containers: $running_containers"
        docker stop $running_containers >/dev/null 2>&1 || true
    fi
    
    # Remove any stopped containers
    local stopped_containers
    stopped_containers=$(docker container prune -f 2>/dev/null || true)
    
    # Clean up temporary files
    if [[ -d "$PROJECT_ROOT/vyos-build" ]]; then
        cd "$PROJECT_ROOT/vyos-build" || true
        # Remove any temporary files but preserve source
        sudo rm -rf ./*.tmp ./*.temp 2>/dev/null || true
    fi
    
    local cleanup_end_time
    cleanup_end_time=$(date +%s)
    local cleanup_duration=$((cleanup_end_time - cleanup_start_time))
    
    log "✅ Cleanup completed in ${cleanup_duration}s"
}

# Simplified main execution
main() {
    start_time=$(date +%s)
    
    log "🎯 VyOS ISO Build Started"
    log "   Timestamp: $TIMESTAMP"
    
    # Run build steps
    check_prerequisites
    pull_container
    update_source
    clean_build
    
    if build_iso; then
        copy_artifacts
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "🎉 Build completed successfully in ${duration}s"
        
        echo ""
        echo "🎉 VyOS ISO build completed successfully!"
        echo "📁 Output directory: $OUTPUT_DIR"
        echo "📊 Build time: ${duration} seconds"
        echo "📝 Build log: $BUILD_LOG"
        
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        error_log "Build failed after ${duration}s"
        
        echo ""
        echo "❌ VyOS ISO build failed!"
        echo "📝 Build log: $BUILD_LOG"
        echo "🔍 Error log: $ERROR_LOG"
        exit 1
    fi
}

# Handle interrupts
trap cleanup EXIT

# Run main function
main "$@"