#!/usr/bin/env fish
# On Linux: downloadRclone $INNERWORKDIR/ArangoDB/build/install/usr/sbin
# On Mac: downloadRclone $INNERWORKDIR/third_party/sbin

function setupSourceInfo
  set -l rcloneRev $argv[1]
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E 's/^Rclone:.*$/Rclone: '"$rcloneRev"'/g' $INNERWORKDIR/sourceInfo.log
end

set -l arch ""

switch "$ARCH"
  case "x86_64"
    set arch "amd64"
  case '*'
    if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
      set arch "arm64"
    else
      echo "fatal, unknown architecture $ARCH for the starter"
      exit 1
    end
end

set -xg RCLONE_REV
if test (count $argv) -lt 1
  echo "You need to supply a path where to download the rclone"
  exit 1
end
set -l RCLONE_FOLDER $argv[1]
if test (count $argv) -lt 2
  if test -f $INNERWORKDIR/ArangoDB/RCLONE_REV
    set RCLONE_REV (cat $INNERWORKDIR/ArangoDB/RCLONE_REV)
  else
    eval "set -xg "(grep RCLONE_GO $INNERWORKDIR/ArangoDB/VERSIONS)
    eval "set -xg "(grep RCLONE_VERSION $INNERWORKDIR/ArangoDB/VERSIONS)    
    set RCLONE_REV golang-"$RCLONE_GO"
    set -xg RCLONE_RELEASE "$RCLONE_REV"_"$ARANGODB_VERSION_MAJOR"."$ARANGODB_VERSION_MINOR"_v"$RCLONE_VERSION"
  end
else
  set RCLONE_REV "$argv[2]"
end
if test "$RCLONE_REV" = latest
  set -l meta (curl -s -L "https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_ORGA/rclone-arangodb/releases/latest")
  or begin ; echo "Finding download asset failed for latest" ; exit 1 ; end
  set RCLONE_REV (echo $meta | jq -r ".name")
  or begin ; echo "Could not parse downloaded JSON" ; exit 1 ; end
end
echo "Using RCLONE $RCLONE_RELEASE"

mkdir -p $RCLONE_FOLDER
set -l RCLONE_PATH $RCLONE_FOLDER/rclone-arangodb
echo "https://$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/rclone-arangodb/releases/download/$RCLONE_REV/"$RCLONE_RELEASE"_rclone-arangodb-$PLATFORM-$arch"
and curl -s -L -o "$RCLONE_PATH" "https://$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/rclone-arangodb/releases/download/$RCLONE_REV/"$RCLONE_RELEASE"_rclone-arangodb-$PLATFORM-$arch"
and apk add file
and file -bL --mime "$RCLONE_PATH" | grep -q '^text'
and chmod 755 "$RCLONE_PATH"
and echo "Rclone ready for build $RCLONE_PATH"
and setupSourceInfo "$RCLONE_RELEASE"
or begin echo "ERROR - cannot download Rclone"; setupSourceInfo "N/A"; exit 1; end
