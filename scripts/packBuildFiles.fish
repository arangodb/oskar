#!/usr/bin/fish

cd $INNERWORKDIR/ArangoDB

if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
  echo "Intentionally don't pack build files for $ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR base!"
  exit 0
end

set -l suffix ""
if test "$ENTERPRISEEDITION" = "On"
  set suffix "e"
end

set builddirs "build js/apps/system/_admin/aardvark/APP/react/build"
echo Working on build directories: $builddirs

rm -rf "$INNERWORKDIR/arangodb3$suffix-$PLATFORM-build_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" &>/dev/null 
eval tar -vczf "$INNERWORKDIR/arangodb3$suffix-$PLATFORM-build_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" $builddirs
