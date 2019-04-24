#!/usr/bin/env fish

# On Linux: downloadSyncer $INNERWORKDIR/ArangoDB/build/install/usr/sbin
# On Mac: downloadSyncer $INNERWORKDIR/third_party/sbin

echo Hello, syncer here, arguments are: $argv

if test -z "$DOWNLOAD_SYNC_USER"
  echo Need DOWNLOAD_SYNC_USER environment variable set!
  exit 1
end

if test -f $INNERWORKDIR/ArangoDB/STARTER_REV
  echo This is a 3.2 version, we do not ship arangosync
  exit 0
end

if test (count $argv) -lt 1
  echo "You need to supply a path where to download the starter"
  exit 1
end
set -l SYNCER_FOLDER $argv[1]

if test (count $argv) -eq 1
  eval "set "(grep SYNCER_REV $INNERWORKDIR/ArangoDB/VERSIONS)
else
  set SYNCER_REV "$argv[2]"
end
if test "$SYNCER_REV" = latest
  set -l meta (curl -s -L "https://$DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/latest")
  or begin ; echo "Finding download asset failed for latest" ; exit 1 ; end
  set SYNCER_REV (echo $meta | jq -r ".name")
  or begin ; echo "Could not parse downloaded JSON" ; exit 1 ; end
end

echo Using DOWNLOAD_SYNC_USER "$DOWNLOAD_SYNC_USER"
echo Using SYNCER_REV "$SYNCER_REV"

# First find the assets and $PLATFORM executable:
set -l meta (curl -s -L https://$DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/tags/$SYNCER_REV)
or begin ; echo Finding download asset failed ; exit 1 ; end

echo $meta > $INNERWORKDIR/assets.json

set -l asset_id (echo $meta | jq ".assets | map(select(.name == \"arangosync-$PLATFORM-amd64\"))[0].id")
if test $status -ne 0
  echo Downloaded JSON cannot be parsed
  exit 1
end
echo Downloading: Asset with ID $asset_id
set -l SYNCER_PATH $SYNCER_FOLDER/arangosync
echo "https://USER@api.github.com/repos/arangodb/arangosync/releases/assets/$asset_id"
curl -s -L -H "Accept: application/octet-stream" "https://$DOWNLOAD_SYNC_USER@api.github.com/repos/arangodb/arangosync/releases/assets/$asset_id" -o "$SYNCER_PATH"
and chmod 755 "$SYNCER_PATH"
and echo Syncer ready for build $SYNCER_PATH
or begin echo "ERROR - cannot download Syncer"; exit 1; end
