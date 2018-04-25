#! /bin/bash

# 获取容器IP地址
host_ip=$(ifconfig eth0 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 替换启动脚本的IP地址
sed -i "19d" apollo-portal/scripts/startup.sh
sed -i "18a\SERVER_URL=\"http:\/\/$host_ip:\$SERVER_PORT\"" apollo-portal/scripts/startup.sh

# 启动apollo-portal服务
/bin/bash apollo-portal/scripts/startup.sh
