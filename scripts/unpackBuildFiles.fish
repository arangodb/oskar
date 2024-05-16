#!/usr/bin/fish

if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
  echo "Intentionally don't unpack build files for $ARANGODB_VERSION_MAJOR.$ARANGODB_VERSION_MINOR base!"
  exit 0
end

set -l BUILD_FILES_ARCHIVE "$argv[1]"

cd $INNERWORKDIR/ArangoDB

if test -z "$BUILD_FILES_ARCHIVE"
  set -l suffix ""
  if test "$ENTERPRISEEDITION" = "On"
    set suffix "e"
  end
  set BUILD_FILES_ARCHIVE $INNERWORKDIR/arangodb3$suffix-$PLATFORM-build_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz
end

echo Extract build files from: $BUILD_FILES_ARCHIVE
eval tar -zxvf "$BUILD_FILES_ARCHIVE" -C .
