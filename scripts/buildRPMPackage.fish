#!/usr/bin/env fish
mkdir -p /root/SPECS
cd $INNERWORKDIR
cp arangodb3.spec /root/SPECS
cp arangodb3.initd arangodb3.service arangodb3.logrotate $INNERWORKDIR/ArangoDB/build/install/usr/share/arangodb3
rpmbuild -bb -vv --define "_binary_filedigest_algorithm 8" /root/SPECS/arangodb3.spec ; or exit 1
cp /root/rpmbuild/RPMS/*/*.rpm $INNERWORKDIR ; or exit 1
chown -R $UID.$GID $INNERWORKDIR
