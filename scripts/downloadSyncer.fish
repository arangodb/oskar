#!/usr/bin/env fish

# On Linux: downloadSyncer $INNERWORKDIR/ArangoDB/build/install/usr/sbin
# On Mac: downloadSyncer $INNERWORKDIR/third_party/sbin


function setupSourceInfo
  set -l syncerRev $argv[1]
  set -l suffix ""
  test $PLATFORM = "darwin"; and set suffix ".bak"
  sed -i$suffix -E 's/^Syncer:.*$/Syncer: '"$syncerRev"'/g' $INNERWORKDIR/sourceInfo.log
end

echo Hello, syncer here, arguments are: $argv

# There is no arangosync in 3.11.14.5 or higher and in 3.12 or higher,
# so do not download it at all:
set -l CMAKELIST "$INNERWORKDIR/ArangoDB/CMakeLists.txt"
if test -f "$CMAKELIST"
  set -l VERSIONSEDFIX 's/.*"\([0-9a-zA-Z]*\)".*$/\1/'
  set -l VMAJOR (grep 'set(ARANGODB_VERSION_MAJOR' $CMAKELIST | sed -e $VERSIONSEDFIX)
  set -l VMINOR (grep 'set(ARANGODB_VERSION_MINOR' $CMAKELIST | sed -e $VERSIONSEDFIX)
  set -l VPATCH (grep 'set(ARANGODB_VERSION_PATCH' $CMAKELIST | grep -v unset | sed -e $VERSIONSEDFIX)
  set -l VRELEASE_TYPE (grep 'set(ARANGODB_VERSION_RELEASE_TYPE' $CMAKELIST | grep -v unset | sed -e $VERSIONSEDFIX)
  set -l SHIPS_ARANGOSYNC "true"
  if test "$VMAJOR" = "3"
    if string match -qr '^[0-9]+$' -- "$VMINOR"
      if test "$VMINOR" -ge 12
        set SHIPS_ARANGOSYNC "false"
      else if test "$VMINOR" -eq 11
        if string match -qr '^[0-9]+$' -- "$VPATCH"
          if test "$VPATCH" -gt 14
            set SHIPS_ARANGOSYNC "false"
          else if test "$VPATCH" -eq 14
            # 3.11.14: hot-fix releases have a purely numeric release type (3.11.14.X)
            if string match -qr '^[0-9]+$' -- "$VRELEASE_TYPE"
              if test "$VRELEASE_TYPE" -ge 5
                set SHIPS_ARANGOSYNC "false"
              end
            end
          end
        end
      end
    end
  end
  if test "$SHIPS_ARANGOSYNC" = "false"
    echo "INFO: ArangoDB $VMAJOR.$VMINOR.$VPATCH does not ship arangosync anymore (gone since 3.11.14.5 and not in 3.12+): skipping arangosync download"
    # sourceInfo.log already contains "Syncer: N/A" from its initialization
    exit 0
  end
end

if test -z "$DOWNLOAD_SYNC_USER"
  echo Need DOWNLOAD_SYNC_USER environment variable set!
  exit 1
end

set -l arch ""

switch "$ARCH"
  case "x86_64"
    set arch "amd64"
  case '*'
    if string match --quiet --regex '^arm64$|^aarch64$' $ARCH >/dev/null
      set arch "arm64"
    else
      echo "fatal, unknown architecture $ARCH for Syncer"
      exit 1
    end
end

# Extract PAT from "user:password" according to
# https://developer.github.com/changes/2020-02-14-deprecating-password-auth/
set -gx DOWNLOAD_SYNC_USER (echo "$DOWNLOAD_SYNC_USER" | cut -d ':' -f 2)

if test -f $INNERWORKDIR/ArangoDB/STARTER_REV
  echo This is a 3.2 version, we do not ship arangosync
  exit 0
end

if test (count $argv) -lt 1
  echo "You need to supply a path where to download the Syncer"
  exit 1
end
set -l SYNCER_FOLDER $argv[1]

if test (count $argv) -eq 1
  eval "set "(grep SYNCER_REV $INNERWORKDIR/ArangoDB/VERSIONS)
else
  set SYNCER_REV "$argv[2]"
end
if test "$SYNCER_REV" = latest
  set -l meta (curl -s -L -H "Authorization: token $DOWNLOAD_SYNC_USER" "https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_ORGA/arangosync/releases/latest")
  or begin ; echo "Finding download asset failed for latest" ; exit 1 ; end
  set SYNCER_REV (echo $meta | jq -r ".name")
  or begin ; echo "Could not parse downloaded JSON" ; exit 1 ; end
end

echo Using DOWNLOAD_SYNC_USER "$DOWNLOAD_SYNC_USER"
echo Using SYNCER_REV "$SYNCER_REV"

# First find the assets and $PLATFORM executable:
set -l meta (curl -s -L -H "Authorization: token $DOWNLOAD_SYNC_USER" https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_ORGA/arangosync/releases/tags/$SYNCER_REV)
or begin ; echo Finding download asset failed ; exit 1 ; end

echo $meta > $INNERWORKDIR/assets.json

set -l asset_id (echo $meta | jq ".assets | map(select(.name == \"arangosync-$PLATFORM-$arch\"))[0].id")
if test $status -ne 0
  echo Downloaded JSON cannot be parsed
  exit 1
end
echo Downloading: Asset with ID $asset_id
set -l SYNCER_PATH $SYNCER_FOLDER/arangosync
echo "https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_ORGA/arangosync/releases/assets/$asset_id"
curl -s -L -H "Accept: application/octet-stream" -H "Authorization: token $DOWNLOAD_SYNC_USER" "https://api.$ARANGODB_GIT_HOST/repos/$ARANGODB_GIT_ORGA/arangosync/releases/assets/$asset_id" -o "$SYNCER_PATH"
and chmod 755 "$SYNCER_PATH"
and echo Syncer ready for build $SYNCER_PATH
and setupSourceInfo "$SYNCER_REV"
or begin echo "ERROR - cannot download Syncer"; setupSourceInfo "N/A"; exit 1; end
