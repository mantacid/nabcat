# Version 1
## 1.0.0
- Initial implementation of program.

## 1.1.0 
- Added `-c` flag for `random` command.

## 1.2.0
-  Implement config file parsing and format.

# Version 2
## 2.0.0
- Transition (most) parameters to new config format.
- *2.0.1*: Remove unused globals.
- *2.0.2*: Fix picker config values being ignored.

# Version 3
## 3.0.0
- Depreciated `$NABCAT_CAT_DIR` environment variable.
- More helpful config header names.
- Fixed options parsing bug in `info` command.
## 3.1.0
-  Implement first-time config generation.
## 3.2.0
- Implemented image previews in `fzf` picker frontend.
- *3.2.1*: Updated help messages.
- *3.2.2*: Fixed config generation.
- *3.2.3*: Fixed `choose` ignoring clipboard settings in config.

# 3.3.0
- Added `locations` header in config to store multiple cat directories. `nabcat` still only checks one default location.
- *3.3.1*: Fixed legacy parsing code for `env.cat-dir` to properly substitute anchor references.
- *3.3.2*: Fixed `info` not returning any info when no flags passed.
- *3.3.3*: Fixed verbose output attempting to print when selection was canceled.

# 3.4.0
- Removed hard dependency on `gum`. This dependency is now optional for if you want to use it as your picker backend.
- added `-q` flag to force-disable verbose output, since it was breaking no-argument usage.
- Running `nabcat` without arguments will not detect if the viewer defined in the config file is installed.
