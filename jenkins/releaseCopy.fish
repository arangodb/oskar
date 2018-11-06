#!/usr/bin/env fish
rm -rf $WORKSPACE/release
and mkdir -p $WORKSPACE/release/snippets
and for e in Community Enterprise
  for d in Linux Windows MacOSX
    mkdir -p $WORKSPACE/release/packages/$e/$d
  end
end

and mv $WORKSPACE/arangodb3[_-]*.deb $WORKSPACE/release/packages/Community/Linux
and mv $WORKSPACE/arangodb3[_-]*.rpm $WORKSPACE/release/packages/Community/Linux
and mv $WORKSPACE/arangodb3-linux-*.tar.gz $WORKSPACE/release/packages/Community/Linux

and mv $WORKSPACE/arangodb3-*.dmg $WORKSPACE/release/packages/Community/MacOSX
and mv $WORKSPACE/arangodb3-macosx-*.tar.gz $WORKSPACE/release/packages/Community/MacOSX

and mv $WORKSPACE/ArangoDB3-*.exe $WORKSPACE/release/packages/Community/Windows
and mv $WORKSPACE/ArangoDB3-*.zip $WORKSPACE/release/packages/Community/Windows

and mv $WORKSPACE/arangodb3e[_-]*.deb $WORKSPACE/release/packages/Enterprise/Linux
and mv $WORKSPACE/arangodb3e[_-]*.rpm $WORKSPACE/release/packages/Enterprise/Linux
and mv $WORKSPACE/arangodb3e-linux-*.tar.gz $WORKSPACE/release/packages/Enterprise/Linux

and mv $WORKSPACE/arangodb3e-*.dmg $WORKSPACE/release/packages/Enterprise/MacOSX
and mv $WORKSPACE/arangodb3e-macosx-*.tar.gz $WORKSPACE/release/packages/Enterprise/MacOSX

and mv $WORKSPACE/ArangoDB3e-*.exe $WORKSPACE/release/packages/Enterprise/Windows
and mv $WORKSPACE/ArangoDB3e-*.zip $WORKSPACE/release/packages/Enterprise/Windows

and mv $WORKSPACE/*.html $WORKSPACE/release/snippets
