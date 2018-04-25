#! /bin/bash

# 获取容器IP地址
host_ip=$(ifconfig eth0 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 替换启动脚本的IP地址
sed -i "19d" apollo-adminservice/scripts/startup.sh
sed -i "18a\SERVER_URL=\"http:\/\/$host_ip:\$SERVER_PORT\"" apollo-adminservice/scripts/startup.sh

# 启动apollo-adminservice服务
/bin/bash apollo-adminservice/scripts/startup.sh
