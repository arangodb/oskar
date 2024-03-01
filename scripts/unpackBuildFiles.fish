#!/usr/bin/fish

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
