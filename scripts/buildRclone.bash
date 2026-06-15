cd /root
go get github.com/mitchellh/gox
git clone -b $RCLONE_VERSION https://github.com/rclone/rclone.git
cd rclone
RCLONE_COMMIT=`git describe --all --tags --long --dirty=-dirty | tr "/" "-"`
echo "Building $RCLONE_VERSION / $RCLONE_COMMIT"
CGO_ENABLED=0 gox \
  -osarch="linux/amd64 linux/arm64" \
  -ldflags="-X main.projectVersion=$RCLONE_VERSION -X main.projectBuild=$RCLONE_COMMIT -w -s" \
  -output="bin/{{.OS}}/{{.Arch}}/rclone" \
  -tags="netgo" \
  ./...
echo "Linux: rclone-arangodb-linux (amd64)"
cp bin/linux/amd64/rclone /data/rclone-arangodb-linux-amd64
echo "Linux: rclone-arangodb-linux (arm64)"
cp bin/linux/amd64/rclone /data/rclone-arangodb-linux-arm64
