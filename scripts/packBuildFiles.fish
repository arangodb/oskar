#!/usr/bin/fish

cd $INNERWORKDIR/ArangoDB

set -l suffix ""
if test "$ENTERPRISEEDITION" = "On"
  set suffix "e"
end

set builddirs "build js/apps/system/_admin/aardvark/APP/react/build"
echo Working on build directories: $builddirs

echo $ARANGODB_VERSION
rm -rf "$INNERWORKDIR/arangodb3$suffix-$PLATFORM-build_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" &>/dev/null 
eval tar -vczf "$INNERWORKDIR/arangodb3$suffix-$PLATFORM-build_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" $builddirs
