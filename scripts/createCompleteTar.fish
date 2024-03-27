#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@github.com

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
  and git clone --progress --single-branch --branch $RELEASE_TAG ssh://git@github.com/arangodb/arangodb ArangoDB-$RELEASE_TAG
  and pushd $INNERWORKDIR/CompleteTar/ArangoDB-$RELEASE_TAG/3rdParty
  and git submodule update --init --force
  and popd
  and eval "set "(grep SYNCER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  and eval "set "(grep STARTER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  or begin popd; return 1; end
  popd
end

function checkoutEnterprise
  echo "Checkout ArangoDB Enterprise $RELEASE_TAG"
  pushd $INNERWORKDIR/CompleteTar/ArangoDB-$RELEASE_TAG
  and git clone --progress --single-branch --branch $RELEASE_TAG ssh://git@github.com/arangodb/enterprise enterprise
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
  and git clone --progress --single-branch --branch $STARTER_REV ssh://git@github.com/arangodb-helper/arangodb Starter-$STARTER_REV
  or begin popd; return 1; end
  popd
end

function checkoutSyncer
  if test -n "$SYNCER_REV"
    echo "Checkout ArangoDB Syncer $SYNCER_REV"
    pushd $INNERWORKDIR/CompleteTar
    and git clone --progress --single-branch --branch $SYNCER_REV ssh://git@github.com/arangodb/arangosync arangosync-$SYNCER_REV
    or begin popd; return 1; end
    popd
    end
end

function checkoutOskar
  echo "Checkout OSKAR"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --progress --single-branch --branch master ssh://git@github.com/arangodb/oskar
  or begin popd; return 1; end
  popd
end

function createTar
  echo "Checkout OSKAR"
  pushd $INNERWORKDIR/CompleteTar
  and tar -c \
      	  -z \
	  --exclude=.git \
	  --exclude=.gitignore \
	  -f ArangoDBe-$RELEASE_TAG.tar.gz \
	  ArangoDB-$RELEASE_TAG Starter-$STARTER_REV arangosync-$SYNCER_REV oskar
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

