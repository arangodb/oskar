set -e

manifest=$1
IMAGE_TAG=$2

[ -z manifest ] && manifest=neunhoef/ubuntubuildarangodb7
# IMAGE_TAG is set within build-image_*.sh and expected to be equal there
[ -z "$IMAGE_TAG" ] && IMAGE_TAG=user

echo "Creating docker multiarch manifest \"${manifest}:${IMAGE_TAG}\":"
set +e; docker manifest rm -f ${manifest}:${IMAGE_TAG} 2>/dev/null; set -e
docker manifest create ${manifest}:${IMAGE_TAG} \
  --amend ${manifest}-x86_64:${IMAGE_TAG} \
  --amend ${manifest}-aarch64:${IMAGE_TAG} \
|| ( echo "Error during docker multiarch manifest creation!"; exit 1 )

echo "To push the manifest please run:"
echo "  docker manifest push --purge ${manifest}:${IMAGE_TAG}"
