cd /root
go get github.com/mitchellh/gox
git clone -b $RCLONE_VERSION https://github.com/rclone/rclone.git
cd rclone
RCLONE_COMMIT=`git describe --all --tags --long --dirty=-dirty | tr "/" "-"`
echo "Building $RCLONE_VERSION / $RCLONE_COMMIT"
CGO_ENABLED=0 gox \
  -osarch="linux/amd64 windows/amd64 darwin/amd64" \
  -ldflags="-X main.projectVersion=$RCLONE_VERSION -X main.projectBuild=$RCLONE_COMMIT" \
  -output="bin/{{.OS}}/{{.Arch}}/rclone" \
  -tags="netgo" \
  ./...
echo "Linux: rclone-arangodb-linux"
cp bin/linux/amd64/rclone /data/rclone-arangodb-linux
echo "Windows: rclone-arangodb-windows.exe"
cp bin/windows/amd64/rclone.exe /data/rclone-arangodb-windows.exe
echo "Darwin: rclone-arangodb-macos"
cp bin/darwin/amd64/rclone /data/rclone-arangodb-macos
