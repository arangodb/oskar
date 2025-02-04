IMAGE = arangodb/ubuntubuildarangodb-311
TAG = $(shell ./latest-tag.sh)

all: amd64 arm64v8 manifest

tag:
	@if [ -z "$TAG" ]; then \
		echo "A new TAG was not provided explicitly or wasn't able to be guessed"\
    "from arangodb/ubuntubuildarangodb-311!"; exit 1; \
	fi

amd64: tag
	docker build -t ${IMAGE}:${TAG}-x86_64 -f Dockerfile.x86-64 .
	docker push ${IMAGE}:${TAG}-x86_64

arm64: tag
	docker build -t ${IMAGE}:${TAG}-arm64v8 -f Dockerfile.arm64 .
	docker push ${IMAGE}:${TAG}-arm64v8

manifest: tag
	./build-manifest.sh ${IMAGE} ${TAG}

