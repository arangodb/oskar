#!/usr/bin/env fish

if test (count $argv) -ne 1
    echo "usage: createCompleteTar.fish <RELEASE-TAG>"
    exit 1
end

set -g RELEASE_TAG $argv[1]
set -g SYNCER_REV "unknown"
set -g STARTER_REV "unknown"

function checkoutCommunity
  echo "Checkout ArangoDB Community $RELEASE_TAG"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --single-branch --branch $RELEASE_TAG git@github.com:arangodb/arangodb ArangoDB-$RELEASE_TAG
  and eval "set "(grep SYNCER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  and eval "set "(grep STARTER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  or begin popd; return 1; end
  popd
end

function checkoutEnterprise
  echo "Checkout ArangoDB Enterprise $RELEASE_TAG"
  pushd $INNERWORKDIR/CompleteTar/ArangoDB-$RELEASE_TAG
  and git clone --single-branch --branch $RELEASE_TAG git@github.com:arangodb/enterprise enterprise
  or begin popd; return 1; end
  popd
end

function findVersion
  pushd $INNERWORKDIR/CompleteTar
  and eval "set "(grep SYNCER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  and eval "set "(grep STARTER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  or begin popd; return 1; end
  popd
end

function checkoutStarter
  echo "Checkout ArangoDB Starter $STARTER_REV"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --single-branch --branch $STARTER_REV git@github.com:arangodb-helper/arangodb Starter-$STARTER_REV
  or begin popd; return 1; end
  popd
end

function checkoutSyncer
  echo "Checkout ArangoDB Syncer $SYNCER_REV"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --single-branch --branch $SYNCER_REV git@github.com:arangodb/arangosync arangosync-$SYNCER_REV
  or begin popd; return 1; end
  popd
end

function checkoutOskar
  echo "Checkout OSKAR"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --single-branch --branch master git@github.com:arangodb/oskar
  or begin popd; return 1; end
  popd
end

function createTar
  echo "Checkout OSKAR"
  pushd $INNERWORKDIR/CompleteTar
  and tar -c -z --exclude-vcs -f ArangoDBe-$RELEASE_TAG.tar.gz ArangoDB-$RELEASE_TAG Starter-$STARTER_REV arangosync-$SYNCER_REV oskar
  or begin popd; return 1; end
  popd
end

rm -rf $INNERWORKDIR/CompleteTar
and mkdir $INNERWORKDIR/CompleteTar
and cd $INNERWORKDIR/CompleteTar
and checkoutCommunity
and checkoutEnterprise
and findVersion
and checkoutStarter
and checkoutSyncer
and checkoutOskar
and createTar

