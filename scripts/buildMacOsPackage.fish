#!/usr/bin/env fish
set -xg IDENTITY "Developer ID Application: ArangoDB GmbH (W7UC4UQXPV)"

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

if test "$ENTERPRISEEDITION" = "On"
  set -g APPNAME ArangoDB3e-CLI.app
else
  set -g APPNAME ArangoDB3-CLI.app
end

rm -rf $INNERWORKDIR/dmg
and mkdir -p $INNERWORKDIR/dmg/$APPNAME
and cp -a $WORKDIR/dmg/$APPNAME $INNERWORKDIR/dmg
and sed -i '' -e "s:@VERSION@:$ARANGODB_DARWIN_UPSTREAM:g" $INNERWORKDIR/dmg/$APPNAME/Contents/Info.plist
and echo "created APP in $INNERWORKDIR/dmg/$APPNAME"
and begin
  pushd $INNERWORKDIR/ArangoDB/build
  and make install DESTDIR=$INNERWORKDIR/dmg/$APPNAME/Contents/Resources
  or begin popd; exit 1; end
popd
end

set -l CODESIGN_OPTS --entitlements $WORKDIR/dmg/entitlement.xml --verbose --force --timestamp --sign $IDENTITY

pushd $INNERWORKDIR/dmg
and for file in $APPNAME/Contents/Resources/opt/arangodb/bin/* $APPNAME/Contents/Resources/opt/arangodb/sbin/*
  if test -f $file -a ! -L $file
    codesign $CODESIGN_OPTS --options runtime $file
  end
end
and codesign $CODESIGN_OPTS $APPNAME
and ../../utils/create-dmg --identity $IDENTITY $APPNAME
# use the name stored in the INFO.PLIST, not APPNAME
and mv "ArangoDB3-CLI $ARANGODB_DARWIN_UPSTREAM.dmg" "$INNERWORKDIR/arangodb3-$ARANGODB_DARWIN_UPSTREAM.x86_64.dmg"
or begin popd; exit 1; end

popd


# ## NOTE: This script can only be called on an existing "build" directory
# cd $INNERWORKDIR/ArangoDB/build
# make packages
# # and move to folder
# and make copy_packages
# and echo Package build in $INNERWORKDIR
