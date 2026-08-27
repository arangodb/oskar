#!/usr/bin/env fish
mkdir -p /root/SPECS
cd $INNERWORKDIR
cp arangodb3.spec /root/SPECS
cp arangodb3.initd arangodb3.service arangodb3.logrotate $INNERWORKDIR/ArangoDB/build/install/usr/share/arangodb3
rpmbuild -bb -vv --define "_binary_filedigest_algorithm 8" /root/SPECS/arangodb3.spec ; or exit 1

# Verify the strip policy on the built packages instead of trusting rpm's
# machinery (its Ubuntu sibling once shipped unstripped client tools with
# an empty debuginfo package): wrong packages must fail the build here.
# Policy: client tools stripped with their debug info in the debuginfo
# package, arangod keeps its (minimal) debug info under ExceptArangod,
# the starter and rclone are never touched.
set -l RPMS /root/rpmbuild/RPMS
set -l V /tmp/rpm-verify
rm -rf $V
mkdir -p $V
cd $V
set -l server (ls $RPMS/*/*.rpm | grep -v -e '\-client\-' -e '\-debuginfo\-' | head -1)
rpm2cpio $server | cpio -idm --quiet
or begin ; echo "buildRPMPackage: cannot unpack $server for verification" ; exit 1 ; end

if test "$PACKAGE_STRIP" = ExceptArangod -o "$PACKAGE_STRIP" = All
  for tool in arangodump arangoexport arangoimport arangorestore arangosh arangovpack arangobench arangobackup
    if test -f usr/bin/$tool
      if readelf -S usr/bin/$tool | grep -q '\.symtab'
        echo "buildRPMPackage: expected usr/bin/$tool to be stripped, but it is not"
        exit 1
      end
    end
  end
  set -l dbg (ls $RPMS/*/*debuginfo*.rpm | head -1)
  if test -z "$dbg"
    echo "buildRPMPackage: debuginfo package was not built"
    exit 1
  end
  if test (rpm2cpio $dbg | cpio -t 2>/dev/null | grep -c '\.debug') -lt 6
    echo "buildRPMPackage: debuginfo package is (nearly) empty"
    exit 1
  end
end
if test "$PACKAGE_STRIP" = ExceptArangod
  if not readelf -S usr/sbin/arangod | grep -q '\.symtab'
    echo "buildRPMPackage: usr/sbin/arangod lost its debug info"
    exit 1
  end
end
cmp -s usr/bin/arangodb $INNERWORKDIR/ArangoDB/build/install/usr/bin/arangodb
or begin ; echo "buildRPMPackage: the starter was modified by packaging" ; exit 1 ; end
if test -f usr/sbin/rclone-arangodb
  cmp -s usr/sbin/rclone-arangodb $INNERWORKDIR/ArangoDB/build/install/usr/sbin/rclone-arangodb
  or begin ; echo "buildRPMPackage: rclone was modified by packaging" ; exit 1 ; end
end
echo "buildRPMPackage: strip policy verified (PACKAGE_STRIP=$PACKAGE_STRIP)"
cd $INNERWORKDIR

cp /root/rpmbuild/RPMS/*/*.rpm $INNERWORKDIR ; or exit 1
chown -R $UID.$GID $INNERWORKDIR
