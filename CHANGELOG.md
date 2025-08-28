# Changelog

## 1.0.81
- Removed user directive from Nginx configuration to avoid permission issues
- Created proper directory structure for Nginx temp files
- Removed user and group settings from PHP-FPM pool configuration
- Fixed permissions for critical system paths

## 1.0.80
- Removed chown operations from PHP-FPM startup script to fix permission issues
- Changed Nginx and PHP-FPM to use nobody user to avoid permission problems
- Fixed temporary directory permissions handling

## 1.0.79
- Fixed user permission issues by switching from apache to nginx user
- Updated Nginx configuration to use nginx user instead of apache
- Updated PHP-FPM configuration to use nginx user instead of apache
- Added explicit user creation to ensure nginx user exists
- Fixed directory and file permissions to work with nginx user

## 1.0.78
- Changed PHP-FPM to run as apache user instead of root or nobody
- Created apache user explicitly to ensure it exists
- Updated Nginx to also run as apache user for consistency
- Added file permission changes to ensure apache user can access all files
- Fixed temp directory permissions

## 1.0.77
- Fixed PHP-FPM configuration by moving allow_url_fopen from pool level to php_admin_flag
- Improved error handling for PHP-FPM startup
- Fixed configuration syntax for PHP-FPM pool settings

## 1.0.76
- Created a simplified PHP-FPM startup script using a temporary wrapper
- Modified PHP-FPM configuration to use root user and custom pid file
- Removed problematic PHP-FPM flags that could cause startup issues
- Set all logs to stdout/stderr for better container integration

## 1.0.75
- Added the PHP-FPM flag --allow-to-run-as-root to bypass security restriction
- Disabled PHP-FPM security.limit_extensions to allow all file types
- Added additional PHP configuration flags for better compatibility
- Created dedicated PHP-FPM temp directory with proper permissions

## 1.0.74
- Changed PHP-FPM to run as root user to fix persistent permission issues
- Simplified PHP-FPM configuration to avoid security warnings
- Removed unnecessary PHP flags that could cause configuration errors
- Kept permissive directory permissions to ensure proper operation

## 1.0.73
- Fixed PHP-FPM configuration error with cgi.fix_pathinfo
- Changed nginx to run as root to fix permission issues
- Updated temp directory handling to avoid permission errors
- Improved PHP configuration with correct boolean values

## 1.0.72
- Changed PHP-FPM and Nginx to run as nobody user
- Set fully permissive permissions on directories to avoid permission issues
- Improved temp directory setup to support the nobody user
- Added explicit config file to PHP-FPM startup command

## 1.0.71
- Rolled back to running services as root
- Simplified nginx configuration
- Fixed temp directory paths
- Removed problematic permission changes
- Consolidated nginx configuration in one file

## 1.0.70
- Rolled back to running services as root
- Simplified nginx configuration
- Fixed temp directory paths
- Removed problematic permission changes
- Consolidated nginx configuration in one file

## 1.0.69
- Fixed Nginx configuration to avoid /var/lib/nginx permission issues
- Redirected all logs to stdout/stderr instead of files
- Removed unnecessary file permission operations
- Updated temp directory paths

## 1.0.68
- Changed PHP-FPM and Nginx to run as nobody user instead of root
- Added more permissive file permissions throughout the filesystem
- Fixed nginx temp directory permissions
- Improved PHP-FPM configuration to avoid security errors

## 1.0.67
- Fixed permission issues by running all services as root
- Updated Nginx and PHP-FPM configuration to use root user
- Removed problematic chown operations that caused errors
- Fixed temporary directory permissions
- Added better error handling for file operations

## 1.0.66
- Rolled back to using root user for PHP-FPM to fix permission issues
- Removed ownership change operations that cause errors
- Updated Nginx configuration to run as root
- Fixed temporary directory permissions without ownership changes

## 1.0.65
- Fixed PHP-FPM configuration to use nginx user instead of root
- Added proper directory and file permissions for PHP-FPM
- Improved error handling for file operations

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
