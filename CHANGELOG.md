# Changelog

## 1.0.64
- Run Nginx and PHP-FPM as root user to avoid permission issues
- Removed chown commands that were failing
- Updated Nginx configuration to use user directive

## 1.0.63
- Enhanced ingress configuration
- Added additional HTTP headers for improved security
- Optimized Nginx configuration for better performance
- Added better error handling for file operations

## 1.0.62
- Fixed PHP-FPM log redirection to stdout/stderr
- Redirected Nginx logs to process stdout
- Added proper ownership for temp directories
- Improved Nginx startup procedure

## 1.0.61
- Fixed enhanced error handling
- Improved Nginx configuration

## 1.0.60
- Fixed Nginx temp directory permissions issue
- Fixed PHP-FPM user/group configuration
- Updated Nginx configuration to avoid ownership checks
- Added custom PHP-FPM configuration file

## 1.0.59
- Fixed permission issues by removing directory/file chmod operations
- Modified Dockerfile to set permissions during build
- Enhanced error handling in scripts
- Using PHP-FPM with root user to avoid permission issues

## 1.0.58
- Fixed Nginx configuration for proper ingress support
- Added additional documentation and examples

## 1.0.57
- Fixed permission issues with nginx and PHP logs
- Added better error handling for file operations
- Improved directory creation and permissions management

## 1.0.56
- Fix unbound variable issue in initialization script
- Improve nginx configuration for ingress
- Update Firefly III to version 6.0.30

## 1.0.55
- Fixed route service provider error

## 1.0.54
- Added proper middleware initialization

## 1.0.53
- Enhanced ingress support
- Fixed PHP processing issues

## 1.0.52
- Initial release
- Added support for Firefly III version 6.0.30
- Added integration with Home Assistant authentication
- Implemented ingress support
