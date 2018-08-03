default: build_all

nginx-haconiwa:
	docker build -t nginx-haconiwa ./nginx-haconiwa
	docker run --rm -v $(PWD)/nginx-haconiwa/builds:/builds -t nginx-haconiwa
	mv ./nginx-haconiwa/builds/nginx* ./dist/

base:
	docker build -t haconiwa-container:base ./container/base

nginx:
	docker build -t haconiwa-container:nginx ./container/nginx
	docker run -d -h nginx --rm --name haconiwa-nginx -t haconiwa-container:nginx
	docker export haconiwa-nginx > ./dist/nginx.image.tar.gz
	docker stop haconiwa-nginx
	docker rmi haconiwa-container:nginx

ssh:
	docker build -t haconiwa-container:ssh ./container/ssh
	docker run -d -h ssh --rm --name haconiwa-ssh -t haconiwa-container:ssh
	docker export haconiwa-ssh > ./dist/ssh.image.tar.gz
	docker stop haconiwa-ssh
	docker rmi haconiwa-container:ssh

postfix:
	docker build -t haconiwa-container:postfix ./container/postfix
	docker run -d -h postfix --rm --name haconiwa-postfix -t haconiwa-container:postfix
	docker export haconiwa-postfix > ./dist/postfix.image.tar.gz
	docker stop haconiwa-postfix
	docker rmi haconiwa-container:postfix

build: base nginx ssh postfix
build_all: nginx-haconiwa build

.PHONY: nginx-haconiwa