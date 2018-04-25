#! /bin/bash

# 停止Apollo容器集群
docker-compose down

# 删除apollo-db镜像
docker rmi apollo-db

# 删除数据库相关目录
rm -rf /usr/local/mysql
