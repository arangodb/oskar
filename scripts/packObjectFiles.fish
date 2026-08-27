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

set v8libs (find build/3rdParty/v8-build -name "*.a")
echo Working on v8 libraries: $v8libs
for l in $v8libs
  echo $l ...
  # ADDLIB copies every member; the old "ar -t | xargs ar rvs" lost
  # duplicate member basenames (V8 has e.g. heap/sweeper.o AND
  # cppgc/sweeper.o) whenever xargs split the list into batches, because
  # "r" REPLACES a member of the same name - shipping archives with
  # silently missing objects. The member count is asserted to match.
  printf 'CREATE %s\nADDLIB %s\nSAVE\nEND\n' "$l.new" "$l" | ar -M
  or begin ; echo "packObjectFiles: ar -M rewrite of $l failed" ; exit 1 ; end
  set -l oldcount (ar -t "$l" | wc -l)
  set -l newcount (ar -t "$l.new" | wc -l)
  if test "$oldcount" != "$newcount"
    echo "packObjectFiles: rewrite of $l lost members ($oldcount -> $newcount)"
    exit 1
  end
  mv "$l.new" "$l"
end

cp -a (find /opt -name "libssl.a") build
cp -a (find /opt -name "libcrypto.a") build
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
echo lib/BuildId/BuildId.ld >> inclusion_list.txt
# The relink script is generated from the link command lines of this
# very build when the source tree ships the generator (3.12.11+): the
# hand-maintained snapshot rotted silently (stale compiler, object and
# library lists). Branches without the generator keep the frozen copy.
set -l CLANG_MAJOR (grep -Po 'CLANG_LINUX "\K[0-9]+' VERSIONS)
if test -f scripts/packaging/generate_link_executables.py -a -n "$CLANG_MAJOR"
  python3 scripts/packaging/generate_link_executables.py (pwd) build "$CLANG_MAJOR" > scripts/link_executables.sh
  and chmod 755 scripts/link_executables.sh
  or begin ; echo "packObjectFiles: generating link_executables.sh failed" ; exit 1 ; end
else
  cp /scripts/link_executables.sh scripts
end
cp /scripts/README.static-linking README.static-linking
if test -n "$CLANG_MAJOR"
  sed -i -E "s/clang-[0-9]+/clang-$CLANG_MAJOR/g; s/lld-[0-9]+/lld-$CLANG_MAJOR/g" README.static-linking
end
echo scripts/link_executables.sh >> inclusion_list.txt
echo README.static-linking >> inclusion_list.txt

rm -rf "$INNERWORKDIR/arangodb3e-$PLATFORM-object_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" &>/dev/null 
eval tar -vczf "$INNERWORKDIR/arangodb3e-$PLATFORM-object_files_$BUILDMODE-$ARANGODB_VERSION"_"$ARCH.tar.gz" --files-from=inclusion_list.txt
