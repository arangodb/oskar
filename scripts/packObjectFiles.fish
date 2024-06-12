#!/usr/bin/fish

# This script is to be executed in the main source directory after a
# successful build with static binaries. It should be run from within
# the build image, such that it has access to the libraries in there.
# The script gathers all the necessary object files, in particular all
# .a files and those .o files of the static executables we ship. It will
# then add a bunch of linking scripts to allow users to rebuild the
# static executables against a newer version of glibc. Everything will
# be delivered in a .tar.gz file.

cd $INNERWORKDIR/ArangoDB

if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
  set v8libs (find build/3rdParty/V8 -name "*.a")
else
  set v8libs (find build/3rdParty/v8-build -name "*.a")
end
echo Working on v8 libraries: $v8libs
for l in $v8libs
  echo $l ...
  ar -t "$l" | xargs ar rvs "$l.new"
  mv "$l.new" "$l"
end

cp -a (find /opt -name "libssl.a") build
cp -a (find /opt -name "libcrypto.a") build
if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
  cp -a (find /opt -name "libldap.a") build
  cp -a (find /opt -name "liblber.a") build
end
find . -name "*.a" > inclusion_list.txt
find . -name "arangovpack.cpp.o" >> inclusion_list.txt
find . -name "arangobackup.cpp.o" >> inclusion_list.txt
find . -name "arangobench.cpp.o" >> inclusion_list.txt
find . -name "arangosh.cpp.o" >> inclusion_list.txt
find . -name "arangodump.cpp.o" >> inclusion_list.txt
find . -name "arangoexport.cpp.o" >> inclusion_list.txt
find . -name "arangorestore.cpp.o" >> inclusion_list.txt
find . -name "arangoimport.cpp.o" >> inclusion_list.txt
find . -name "arangod.cpp.o" >> inclusion_list.txt
find build/client-tools -name "*.cpp.o" >> inclusion_list.txt
if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -gt 11
  echo lib/BuildId/BuildId.ld >> inclusion_list.txt
end
if test "$ARANGODB_VERSION_MAJOR" -eq 3; and test "$ARANGODB_VERSION_MINOR" -lt 12
  cp /scripts/link_executables_3.11.sh scripts/link_executables.sh
else
  cp /scripts/link_executables.sh scripts
end
cp /scripts/README.static-linking README.static-linking
echo scripts/link_executables.sh >> inclusion_list.txt
echo README.static-linking >> inclusion_list.txt

rm -rf "$INNERWORKDIR/arangodb3e-$PLATFORM-object_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" &>/dev/null 
eval tar -vczf "$INNERWORKDIR/arangodb3e-$PLATFORM-object_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" --files-from=inclusion_list.txt

