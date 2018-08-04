#!/bin/bash -e

nginx_ver=1.13.12
common_name=fastcontainer.local
images=("nginx" "ssh" "postfix")

apt upgrade -y
apt install -y bridge-utils openssl curl
locale-gen ja_JP.UTF-8

# install haconiwa
type haconiwa >/dev/null 2>&1 || \
  curl -s https://packagecloud.io/install/repositories/udzura/haconiwa/script.deb.sh | bash && \
  apt install -y haconiwa

# deploy hacofile
test -d /var/lib/haconiwa || mkdir -p /var/lib/haconiwa
rm -rf /var/lib/haconiwa/hacos && ln -s /data/hacos /var/lib/haconiwa/hacos
test -d /var/lib/haconiwa/rootfs || mkdir -p /var/lib/haconiwa/rootfs

# deploy container images
for ((i = 0; i < ${#array[@]}; i++)) {
  test -d /var/lib/haconiwa/rootfs/${images[i]} || mkdir /var/lib/haconiwa/rootfs/${images[i]}
  tar xfp /data/dist/${images[i]}.image.tar.gz -C /var/lib/haconiwa/rootfs/${images[i]}
  test -d /var/log/haconiwa/${images[i]} || mkdir -p /var/log/haconiwa/${images[i]}
}

# setup network
brctl show haconiwa0 2>&1 | grep -i "no such device" && brctl addbr haconiwa0
ip addr show haconiwa0 2>&1 | grep "10.0.5.1/24" || \
  ip addr add 10.0.5.1/24 dev haconiwa0 && ip link set dev haconiwa0 up
test $(/sbin/sysctl net.ipv4.ip_forward | awk '{print $3}') -eq 0 && \
  /sbin/sysctl -w net.ipv4.ip_forward=1
/sbin/iptables-restore < /data/iptables.rules

# install nginx
cp /data/dist/nginx-${nginx_ver}.tar.gz /usr/local/src/nginx.tar.gz
tar xf /usr/local/src/nginx.tar.gz -C /usr/local/
test -d /etc/nginx || ln -s /usr/local/nginx-${nginx_ver}/conf /etc/nginx
test -x /usr/sbin/nginx || ln -s /usr/local/nginx-${nginx_ver}/sbin/nginx /usr/sbin/nginx
test -d /var/log/nginx || ln -s /usr/local/nginx-${nginx_ver}/logs /var/log/nginx
id nginx >/dev/null 2>&1 || useradd -d /var/www -s /bin/false nginx

test -f /etc/systemd/system/nginx.service || \
  cp /data/nginx/nginx.service /etc/systemd/system/nginx.service && systemctl daemon-reload
rm -rf /etc/nginx/nginx.conf && \
  ln -s /data/nginx/nginx.conf /etc/nginx/nginx.conf
rm -rf /etc/nginx/conf.d && \
  ln -s /data/nginx/conf.d /etc/nginx/conf.d

test -f /etc/nginx/tls.key || \
  openssl req -x509 -days 365 -newkey rsa:2048 -nodes \
  -out /etc/nginx/tls.crt -keyout /etc/nginx/tls.key \
  -subj "/C=/ST=/L=/O=/OU=/CN=${common_name}" >/dev/null 2>&1

systemctl enable nginx && systemctl start nginx