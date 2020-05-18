#!/usr/bin/env fish
set -xg IDENTITY "Developer ID Application: ArangoDB GmbH (W7UC4UQXPV)"

# sanity checks
if test -z "$NOTARIZE_USER"
  echo "Need NOTARIZE_USER environment variable set!"
  exit 1
end

if test -z "$NOTARIZE_PASSWORD"
  echo "Need NOTARIZE_PASSWORD environment variable set!"
  exit 1
end

if test -z "$MACOS_ADMIN_KEYCHAIN_PASS"
  echo "Need MACOS_ADMIN_KEYCHAIN_PASS environment variable set!"
  echo "Set to '-' for interactive mode"
  exit 1
end

if test -z $argv[1]
  echo "Need ArangoDB MAJOR.MINOR version the parameter!"
  exit 1
end

# unlock keychain to make code signing work
if test "$MACOS_ADMIN_KEYCHAIN_PASS" = "-"
  security unlock-keychain
else
  security unlock-keychain -p $MACOS_ADMIN_KEYCHAIN_PASS
end

set -g pd "default"

if test -d $WORKDIR/dmg/$argv[1]
  set -g pd $argv[1]
end

if test "$ENTERPRISEEDITION" = "On"
  set -g APPNAME ArangoDB3e-CLI.app
  set -g PKGNAME arangodb3e
  set -g EDITION "Enterprise"
else
  set -g APPNAME ArangoDB3-CLI.app
  set -g PKGNAME arangodb3
  set -g EDITION "Community"
end

set -g DMGNAME (basename $APPNAME .app).dmg

# helper functions
function setupApp
  cp -aL $WORKDIR/dmg/$pd/$APPNAME $INNERWORKDIR/dmg
  and sed -i '' -e "s:@VERSION@:$ARANGODB_DARWIN_UPSTREAM:g" $INNERWORKDIR/dmg/$APPNAME/Contents/Info.plist
  and echo "created APP in $INNERWORKDIR/dmg/$APPNAME"
  and begin
    pushd $INNERWORKDIR/ArangoDB/build
    and make install DESTDIR=$INNERWORKDIR/dmg/$APPNAME/Contents/Resources
    and if test "$ENTERPRISEEDITION" = "On"
          pushd $INNERWORKDIR/dmg/$APPNAME/Contents/Resources/opt/arangodb/bin
          ln -s ../sbin/arangosync
          popd
        end
    and popd
    or begin popd; exit 1; end
  end
end

function codeSignApp
  set -l CODESIGN_OPTS --entitlements $WORKDIR/dmg/entitlement.xml --verbose --force --timestamp --sign $IDENTITY

  and for file in $APPNAME/Contents/Resources/opt/arangodb/bin/* $APPNAME/Contents/Resources/opt/arangodb/sbin/*
    if test -f $file -a ! -L $file
      codesign $CODESIGN_OPTS --options runtime $file
    end
  end
  and codesign $CODESIGN_OPTS $APPNAME
end

set -g UPLOAD_LOG $INNERWORKDIR/mac_upload.log
set -g PROGRESS_LOG $INNERWORKDIR/mac_progress.log
set -g RESULT_LOG $INNERWORKDIR/mac_result.log

rm -f $UPLOAD_LOG $PROGRESS_LOG $RESULT_LOG

function uploadApp
  fish -c "while true; sleep 60; echo Uploading == (date) ==; end" &
  set ep (jobs -p | tail -1)
  and zip -q -r $APPNAME.zip $APPNAME
  and xcrun altool --notarize-app -t osx -f $APPNAME.zip --primary-bundle-id org.arangodb.ArangoDB-CLI -u $NOTARIZE_USER -p $NOTARIZE_PASSWORD > $UPLOAD_LOG
  and begin
    kill $ep
    true
  end
  or begin kill $ep; exit 1; end

  if fgrep -q 'No errors uploading' $UPLOAD_LOG
    set -g UPLOAD_ID (fgrep 'RequestUUID' $UPLOAD_LOG | awk '{print $3}')

    if test -z "$UPLOAD_ID"
      echo "Cannot extract upload up"
      cat $UPLOAD_LOG
      return 1
    end

    echo "Upload ID: $UPLOAD_ID"

    return 0
  else
    echo "Uploading failed:"
    cat $UPLOAD_LOG
    return 1
  end
end

function waitForProgress
  sleep 60
  xcrun altool --notarization-info $UPLOAD_ID -u $NOTARIZE_USER -p $NOTARIZE_PASSWORD > $PROGRESS_LOG

  while fgrep -q 'No errors getting notarization info' $PROGRESS_LOG;
    if not fgrep -q 'Status: in progress' $PROGRESS_LOG
      return 0
    end

    date
    fgrep "Status:" $PROGRESS_LOG
    sleep 60
    xcrun altool --notarization-info $UPLOAD_ID -u $NOTARIZE_USER -p $NOTARIZE_PASSWORD > $PROGRESS_LOG
  end

  echo "Cannot get update info"
  cat $PROGRESS_LOG
  return 1
end

function getLogFile
  set logfile (fgrep LogFileURL: $PROGRESS_LOG  | awk '{print $2}')
  and test -n "$logfile"
  or begin
    echo "cannot extract log file url"
    cat $PROGRESS_LOG
    return 1
  end

  curl "$logfile" > $RESULT_LOG
end

function checkNotarization
  if not fgrep -q 'Status: success' $PROGRESS_LOG
    echo "Notarization failed"
    and cat $PROGRESS_LOG
    and getLogFile
    and cat $RESULT_LOG
    return 1
  else
    echo "Notarization succeeded"
    and getLogFile
    return 0
  end
end

function stapleApp
  xcrun stapler staple $APPNAME
end

function createDmg
  fmt -w 70 $APPNAME/Contents/Resources/opt/arangodb/share/doc/arangodb3/LICENSE.txt > LICENSE.txt
  and ../../utils/create-dmg \
    --volname "ArangoDB $EDITION $ARANGODB_DARWIN_UPSTREAM" \
    --eula LICENSE.txt \
    --window-size 800 400 \
    --icon "$APPNAME" 200 190 \
    --app-drop-link 600 185 \
    --no-internet-enable \
    $DMGNAME $APPNAME
end

# create app, notarize and create dmg
rm -rf $INNERWORKDIR/dmg
and mkdir -p $INNERWORKDIR/dmg
and pushd $INNERWORKDIR/dmg
and setupApp
and codeSignApp
and if test $NOTARIZE_APP = On
  uploadApp
  and waitForProgress
  and checkNotarization
  and stapleApp
end
and createDmg
and mv $DMGNAME "$INNERWORKDIR/$PKGNAME-$ARANGODB_DARWIN_UPSTREAM.x86_64.dmg"
or begin popd; exit 1; end

popd
