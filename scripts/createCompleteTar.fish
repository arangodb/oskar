#!/usr/bin/env fish
ssh -o StrictHostKeyChecking=no -T git@$ARANGODB_GIT_HOST
if test "$ENTERPRISEEDITION" = "On"; ssh -o StrictHostKeyChecking=no -T git@$ENTERPRISE_GIT_HOST; end

if test (count $argv) -ne 1
    echo "usage: createCompleteTar.fish <RELEASE-TAG>"
    exit 1
end

set -g RELEASE_TAG $argv[1]
set -g SYNCER_REV "unknown"
set -g STARTER_REV "unknown"

function checkoutCommunity
  echo "================================================================================"
  echo "Checkout ArangoDB Community $RELEASE_TAG"
  echo "================================================================================"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --progress --single-branch --branch $RELEASE_TAG ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/arangodb ArangoDB-$RELEASE_TAG
  and pushd $INNERWORKDIR/CompleteTar/ArangoDB-$RELEASE_TAG/3rdParty
  and git submodule update --init --force
  and popd
  and eval "set "(grep SYNCER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  and eval "set "(grep STARTER_REV ArangoDB-$RELEASE_TAG/VERSIONS)
  or begin popd; return 1; end
  popd
end

function checkoutEnterprise
  echo "================================================================================"
  echo "Checkout ArangoDB Enterprise $RELEASE_TAG"
  echo "================================================================================"
  pushd $INNERWORKDIR/CompleteTar/ArangoDB-$RELEASE_TAG
  and git clone --progress --single-branch --branch $RELEASE_TAG ssh://git@$ENTERPRISE_GIT_HOST/$ENTERPRISE_GIT_ORGA/enterprise enterprise
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
  echo "================================================================================"
  echo "Checkout ArangoDB Starter $STARTER_REV"
  echo "================================================================================"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --progress --single-branch --branch $STARTER_REV ssh://git@$ARANGODB_GIT_HOST/$HELPER_GIT_ORGA/arangodb Starter-$STARTER_REV
  or begin popd; return 1; end
  popd
end

function checkoutSyncer
  if test -n "$SYNCER_REV" -a "$SYNCER_REV" != "unknown"
    echo "================================================================================"
    echo "Checkout ArangoDB Syncer $SYNCER_REV"
    echo "================================================================================"
    pushd $INNERWORKDIR/CompleteTar
    and git clone --progress --single-branch --branch $SYNCER_REV ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/arangosync arangosync-$SYNCER_REV
    or begin popd; return 1; end
    popd
  end
end

function checkoutOskar
  echo "================================================================================"
  echo "Checkout OSKAR"
  echo "================================================================================"
  pushd $INNERWORKDIR/CompleteTar
  and git clone --progress --single-branch --branch master ssh://git@$ARANGODB_GIT_HOST/$ARANGODB_GIT_ORGA/oskar
  or begin popd; return 1; end
  popd
end

function createTar
  echo "================================================================================"
  echo "Creating TAR"
  echo "================================================================================"
  pushd $INNERWORKDIR/CompleteTar
  and if test -n "$SYNCER_REV" -a "$SYNCER_REV" != "unknown"
    tar -c \
       	  -z \
	  --exclude=.git \
	  --exclude=.gitignore \
	  -f ArangoDBe-$RELEASE_TAG.tar.gz \
	  ArangoDB-$RELEASE_TAG Starter-$STARTER_REV arangosync-$SYNCER_REV oskar
  else
    tar -c \
       	  -z \
	  --exclude=.git \
	  --exclude=.gitignore \
	  -f ArangoDBe-$RELEASE_TAG.tar.gz \
	  ArangoDB-$RELEASE_TAG Starter-$STARTER_REV oskar
  end
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

