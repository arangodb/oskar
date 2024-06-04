IMAGE = arangodb/ubuntubuildarangodb-3.11
#TAG = $(shell ./latest-tag.sh)
TAG = 1

all: amd64 arm64v8 manifest

tag:
	@if [ -z "$TAG" ]; then \
		echo "A new TAG was not provided explicitly or wasn't able to be guessed"\
    "from arangodb/ubuntubuildarangodb-3.11!"; exit 1; \
	fi

amd64: tag
	docker build -t ${IMAGE}:${TAG}-x86_64 -f Dockerfile.x86-64 .
	docker push ${IMAGE}:${TAG}-x86_64

arm64: tag
	docker build -t ${IMAGE}:${TAG}-arm64v8 -f Dockerfile.arm64 .
	docker push ${IMAGE}:${TAG}-arm64v8

manifest: tag
	./build-manifest.sh ${IMAGE} ${TAG}

