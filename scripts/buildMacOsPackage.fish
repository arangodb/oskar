#!/usr/bin/env fish

## unlock keychain to make code signing work
if test -z "$MACOS_ADMIN_KEYCHAIN_PASS"
  echo "Need MACOS_ADMIN_KEYCHAIN_PASS environment variable set!"
  echo "Set to '-' for interactive mode"
  exit 1
end

if test "$MACOS_ADMIN_KEYCHAIN_PASS" = "-"
  security unlock-keychain
else
  security unlock-keychain -p $MACOS_ADMIN_KEYCHAIN_PASS
end

## NOTE: This script can only be called on an existing "build" directory
cd $INNERWORKDIR/ArangoDB/build
make packages
# and move to folder
and make copy_packages
and echo Package build in $INNERWORKDIR
