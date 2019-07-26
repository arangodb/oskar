#!/bin/bash
set -e

cat > README.md <<'EOF'
# RPM Build Script

This file will create an RPM package from a given zip archive.

## Requirement

A Linux system with bash and docker as well as access to docker hub.

## Usage

Copy the file `ArangoDB-3.3.23.zip` and the script `build.sh` into
an empty directory.

Switch into this directory.

Run the script with the archive as sole argument

    ./build.sh ArangoDB-3.3.23.zip

This will generated the RPM, Debian and TAR archives for the given version.
EOF

DOCKER_IMAGE=arangodb/oskar:1.0

if test "$#" -ne 1; then
  echo "usage: $0 <archive>"
  exit 1
fi

NAME="$1"

if test ! -f "$NAME"; then
  echo "FATAL: archive '$NAME' not found"
  exit 1
fi

rm -rf builddir
mkdir builddir

(
  cd builddir

  case $NAME in
    *.zip)
      echo "INFO: extracting archive $NAME"
      unzip -q -x "../$NAME"
      ;;
    *.tar.gz)
      echo "INFO: extracting archive $NAME"
      tar xvf "../$NAME"
      ;;
    *)
      echo "FATAL: unknown archive type '$NAME'"
      exit 1
  esac
)

ARANGODB_FILE=$(basename builddir/ArangoDB-*)
STARTER_FILE=$(basename builddir/ArangoDBStarter-*)
SYNCER_FILE=$(basename builddir/arangosync-*)

STARTER_VERSION=$(basename builddir/ArangoDBStarter-* | awk -F- '{print $2}')
SYNCER_VERSION=$(basename builddir/arangosync-* | awk -F- '{print $2}')

echo "INFO: ArangoDB Version: $ARANGODB_FILE"
echo "INFO: Starter Version:  $STARTER_FILE"
echo "INFO: Syncer Version:   $SYNCER_FILE"

echo "INFO: cleaning old directories 'work' and 'oskar'"

docker run \
  --privileged \
  -v "$(pwd):/data" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$DOCKER_IMAGE" fish -c "rm -rf /data/oskar  /data/work"

mkdir work
mkdir oskar

echo "INFO: copying 'work/ArangoDB'"
cp -a "builddir/$ARANGODB_FILE" "work/ArangoDB"

echo "INFO: copying 'work/starter'"
cp -a "builddir/$STARTER_FILE" "work/starter"

echo "INFO: copying 'work/syncer'"
cp -a "builddir/$SYNCER_FILE" "work/syncer"

cat > work/createPackage.fish <<'EOF'

mkdir -p "$OSKAR_HOME/oskar/work"

cp -a /oskar/* "$OSKAR_HOME/oskar"
cp -a /work/ArangoDB "$OSKAR_HOME/oskar/work"
cp -a /work/starter "$OSKAR_HOME/oskar/work/"
cp -a /work/syncer "$OSKAR_HOME/oskar/work/"

mkdir -p "$OSKAR_HOME/oskar/work/ArangoDB/upgrade-data-tests"

function createPackage
  cd "$OSKAR_HOME/oskar"
  source helper.fish

  findArangoDBVersion
  and asanOff
  and maintainerOff
  and releaseMode
  and enterprise
  and set -xg NOSTRIP dont
  and echo "INFO: building 'ArangoDB'"
  and buildStaticArangoDB -DTARGET_ARCHITECTURE=nehalem
  and echo "INFO: finished building 'ArangoDB'"
  and mkdir -p work/ArangoDB/build/install/usr/bin
  and cp "$OSKAR_HOME/oskar/work/starter/arangodb" "work/ArangoDB/build/install/usr/bin"
  and cp "$OSKAR_HOME/oskar/work/syncer/arangosync" "work/ArangoDB/build/install/usr/sbin"
  and copyRclone
  and echo "INFO: building package"
  and buildPackage

  if test "$status" -ne 0
    echo "FATAL: Building enterprise release failed, stopping."
    return 1
  end
end

function createStarter
  pushd "$OSKAR_HOME/oskar/work/starter"
  and set -xg GOPATH (pwd)/.gobuild
  and echo "INFO: building 'Starter' $STARTER_VERSION"
  and echo "INFO: ignore ANY git error messages"
  and make NODOCKER=1 deps
  and go build -ldflags "-extldflags -static -X main.projectVersion=$STARTER_VERSION -X main.projectBuild=$STARTER_VERSION" -o arangodb github.com/arangodb-helper/arangodb
  and echo "INFO: finished building 'Starter'"
  and popd
  or begin
    popd
    echo "FATAL: failed to build 'Starter', stopping."
    return 1
  end
end

function createSyncer
  pushd $OSKAR_HOME/oskar/work/syncer
  and set -xg GOPATH (pwd)/.gobuild
  and echo "INFO: building 'Syncer' $SYNCER_VERSION"
  and echo "INFO: ignore ANY git error messages"
  and make COMMIT=$SYNCER_VERSION local
  and echo "INFO: finished building 'Syncer'"
  and popd
  or begin
    popd
    echo "FATAL: failed to build 'Syncer', stopping."
    return 1
  end
end

function create
  createStarter
  and createSyncer
  and createPackage
end

create
EOF

docker run \
  --privileged \
  -it \
  -e "OSKAR_HOME=$(pwd)" \
  -e "STARTER_VERSION=$STARTER_VERSION" \
  -e "SYNCER_VERSION=$SYNCER_VERSION" \
  -v "$(pwd)/work:/work" \
  -v "$(pwd)/oskar:$(pwd)/oskar" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  "$DOCKER_IMAGE" fish /work/createPackage.fish

cp oskar/work/arangodb3*{rpm,deb,gz} .

echo "INFO: files have been created"
ls -l arangodb3*{rpm,deb,gz}
