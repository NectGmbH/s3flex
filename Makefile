TAG=v0.0.2
IMAGE=kavatech/s3flex:$(TAG)

export GOOS=linux

build:
	go build

docker-build:
	docker build -t $(IMAGE) .

docker-push:
	docker push $(IMAGE)

deploy:
	kubectl apply -f s3flex-ds.yaml
	kubectl delete pods -n s3flex --all