IMAGE = arangodb/ubuntubuildarangodb8
TAG = 1

all: amd64 manifest

amd64:
	docker build -t ${IMAGE}-x86_64:${TAG} .
	docker push ${IMAGE}-x86_64:${TAG}

manifest:
	./build-manifest.sh ${IMAGE} ${TAG}

arm64:
	docker build -t ${IMAGE}-arm64:${TAG} .
	docker push ${IMAGE}-arm64:${TAG}


