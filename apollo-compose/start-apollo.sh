#! /bin/bash

# 创建必要的目录和文件
mkdir -p /usr/local/mysql/{data,log,config}
touch /usr/local/mysql/log/mysqld.log
cp my.cnf /usr/local/mysql/config/
chown -R 27:27 /usr/local/mysql

# 获取本机IP地址
host_ip=$(ifconfig ens3 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 向docker-compose.yml添加主机IP地址
rm -rf docker-compose.yml
cp docker-compose.yml.bak docker-compose.yml
sed -i "12a\      HOST_IP: ${host_ip}" docker-compose.yml
sed -i "29s\-Deureka.instance.ip-address=localhost\-Deureka.instance.ip-address=${host_ip}\g" docker-compose.yml
sed -i "61s\-Ddev_meta=http://localhost:8080/\-Ddev_meta=http://${host_ip}:8080/\g" docker-compose.yml

# 启动Apollo容器集群
docker-compose up -d
