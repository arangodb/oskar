#!/usr/bin/env fish
# On Linux: downloadStarter $INNERWORKDIR/ArangoDB/build/install/usr/bin
# On Mac: downloadStarter $INNERWORKDIR/third_party/bin

function setupSourceInfo
  set -l starterRev $argv[1]
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E 's/^Starter:.*$/Starter: '"$starterRev"'/g' $INNERWORKDIR/sourceInfo.log
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

set -l STARTER_REV

if test (count $argv) -lt 1
  echo "You need to supply a path where to download the starter"
  exit 1
end
set -l STARTER_FOLDER $argv[1]
if test (count $argv) -lt 2
  if test -f $INNERWORKDIR/ArangoDB/STARTER_REV
    set STARTER_REV (cat $INNERWORKDIR/ArangoDB/STARTER_REV)
  else
    eval "set "(grep STARTER_REV $INNERWORKDIR/ArangoDB/VERSIONS)
  end
else
  set STARTER_REV "$argv[2]"
end
if test "$STARTER_REV" = latest
  set -l meta (curl -s -L "https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_STARTER_ORGA/$ARANGODB_GIT_ORGA/releases/latest")
  or begin ; echo "Finding download asset failed for latest" ; exit 1 ; end
  set STARTER_REV (echo $meta | jq -r ".name")
  or begin ; echo "Could not parse downloaded JSON" ; exit 1 ; end
end
echo Using STARTER_REV "$STARTER_REV"

mkdir -p $STARTER_FOLDER
set -l STARTER_PATH $STARTER_FOLDER/arangodb
echo "https://$ARANGODB_GIT_HOST/$ARANGODB_GIT_STARTER_ORGA/$ARANGODB_GIT_ORGA/releases/download/$STARTER_REV/arangodb-$PLATFORM-$arch"
and curl -s -L -o "$STARTER_PATH" "https://$ARANGODB_GIT_HOST/$ARANGODB_GIT_STARTER_ORGA/$ARANGODB_GIT_ORGA/releases/download/$STARTER_REV/arangodb-$PLATFORM-$arch"
and chmod 755 "$STARTER_PATH"
and echo Starter ready for build $STARTER_PATH
and setupSourceInfo "$STARTER_REV"
or begin echo "ERROR - cannot download Starter"; setupSourceInfo "N/A"; exit 1; end
