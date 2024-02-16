In order to build a version of rclone one has to run the following script on a build machine with docker installed (example for rclone-1.65.2):
```
VER=v1.65.2
rm -rf ./rclone
git clone https://github.com/rclone/rclone.git && cd ./rclone
git checkout $VER
docker run --rm -v "$(pwd):/rclone" -v "${HOME}:/user" -e "GOPATH=/user/rclone_go/go" -e "GOCACHE=/user/rclone_go/cache" -u "${UID}:${GID}" -w /rclone golang:1.21.6 bash +x -c 'cd /rclone; function build { GOOS=$1 GOARCH=$2 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X github.com/rclone/rclone/fs.VersionSuffix= " -tags cmount -o /rclone/rclone-arangodb-$(echo $1 | sed "s/darwin/macos/g")-$2$([[ $1 == "windows" ]] && echo ".exe"); }; go get -u golang.org/x/sys; build linux amd64; build linux arm64; build darwin amd64; build darwin arm64; build windows amd64' && \
cd .. && rm -rf $VER; mkdir $VER && mv ./rclone/rclone-arangodb-*-* $VER && rm -rf ./rclone

```
