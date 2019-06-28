#!/usr/bin/env fish
if test -z "$RELEASE_TAG"
  echo "RELEASE_TAG required"
  exit 1
end

source jenkins/helper.jenkins.fish ; prepareOskar

lockDirectory ; updateOskar ; clearResults ; cleanWorkspace

switchBranches "$RELEASE_TAG" "$RELEASE_TAG" true
and findArangoDBVersion
or begin unlockDirectory ; exit 1 ; end

set -l SOURCE /mnt/buildfiles/stage2/$ARANGODB_PACKAGES/packages

function unpack
  set -l filename $argv[1]

  rm -rf work/sandbox
  mkdir -p work/sandbox

  switch $filename
    case '*.tar.gz'
      cp $filename work/sandbox
      or exit 1

    case '*.tar'
      cp $filename work/sandbox
      or exit 1

    case '*.zip'
      cp $filename work/sandbox
      or exit 1

    case '*.exe'
      cp $filename work/sandbox
      or exit 1

    case '*.dmg'
      cp $filename work/sandbox
      or exit 1

    case '*.deb'
      pushd work/sandbox
        ar x $filename
        or exit 1
      popd

    case '*.rpm'
      pushd work/sandbox
        begin rpm2cpio $filename | cpio -i -d; end
        or exit 1
      popd

    case '*.html'
      cp $filename work/sandbox
      or exit 1

    case '*'
      echo "FATAL: unknown file type in '$filename'"
      exit 1
  end
end

set -g infected 0

function scan
  set -l filename $argv[1]

  if test -f $filename
    echo "================================================================================"
    echo "Scanning $filename"

    set -l signature $filename".clamav"
    set -l shaf (sha256sum $filename | awk '{print $1}')

    set -l generateSignature 1

    if test -f $signature
      set -l shas (head -1 $signature | awk '{print $1}')

      if test "$shas" = "$shaf"
        if grep -q "SCAN SUMMARY" $signature
          echo "Found matching old signature $signature"
          set generateSignature 0
        else
          echo "removing empty signature $signature"
          rm -f $signature
        end
      else
        echo "removing non-matching old signature $signature ($shas != $shaf)"
        rm -f $signature
      end
    end

    if test "$generateSignature" -eq 1
      unpack $filename

      begin
        echo $shaf
        echo
        echo "Filename: " (basename $filename)
        echo "Date: " (date)
        echo
        clamscan -r -v --max-scansize=2000M --max-filesize=1000M --max-recursion=10 work/sandbox
        if test $status -gt 1
           exit 1
        end
      end > $signature

      rm -rf work/sandbox
    end

    fgrep "Infected files:" $signature
    or begin
      echo "FATAL: scanning failed, 'Infected files' line not found"
      exit 1
    end

    set infected (expr $infected + (awk '/^Infected files:/ {print $3}' $signature))
  end
end

for i in (find $SOURCE ! -name "*.clamav" -a ! -name "*.asc" -a -type f | fgrep -v .revoked)
  scan $i
end

tar -c -v -z -f (pwd)/clamav-report.tar -C $SOURCE (cd $SOURCE; and find . -name "*.clamav")

echo "Infected files: $infected"

unlockDirectory

if test $infected -gt 0
  exit 1
end
