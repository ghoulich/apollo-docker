Apollo（阿波罗）是携程框架部门研发的分布式配置中心，在不考虑高可用和负载均衡的情况下，它最少需要四个组件才能最小化运行，分别是：

- apollo-configservice：提供配置管理服务，如果有多套环境，那么每个环境都需要部署。内置Eureka服务器。
- apollo-adminService：提供后台管理服务，如果有多套环境，那么每个环境都需要部署。
- apollo-portal：提供Web用户界面，只需要部署一个服务即可。
- apollo-db：基于MySQL，包含ApolloConfigDB和ApolloPortalDB数据库。

本文将为上述几个组件制作Docker镜像，然后通过服务编排的方式容器化部署Apollo服务，借此提高部署的灵活性，并且简化部署过程。

## 一、环境描述

#### 1. 宿主机

- CPU：双核
- 内存：4 GB
- 硬盘：120 GB
- IP：192.168.190.128
- 操作系统：CentOS 7.4-1708 x86_64 Minimal

#### 2. Docker

- 版本：1.12.6
- 安装方式：参考《[如何通过yum安装Docker和Docker-Compose](http://ghoulich.xninja.org/2017/09/21/how-to-install-docker-and-docker-compose-with-yum-on-centos/ "如何通过yum安装Docker和Docker-Compose")》

#### 3. Docker Compose

- 版本：1.19.0
- 安装方式：参考《[如何通过yum安装Docker和Docker-Compose](http://ghoulich.xninja.org/2017/09/21/how-to-install-docker-and-docker-compose-with-yum-on-centos/ "如何通过yum安装Docker和Docker-Compose")》

## 二、制作apollo-configservice镜像

#### 1. 获取压缩包

在shell中运行以下命令，创建制作apollo-configservice镜像的专用目录：

```shell
mkdir -pv /root/Downloads/apollo-configservice-build
```

根据《[如何编译安装Apollo服务器（单机版）](http://ghoulich.xninja.org/2018/04/24/how-to-build-and-install-apollo-in-standalone-mode/ "如何编译安装Apollo服务器（单机版）")》编译Apollo的源码，获得`apollo-configservice-0.11.0-SNAPSHOT-github.zip`压缩包文件，然后将其放至`/root/Downloads/apollo-configservice-build`目录。

#### 2. 创建启动脚本

在shell中运行以下命令，创建容器使用的apollo-configservice服务的启动脚本：

```shell
cd /root/Downloads/apollo-configservice-build/
cat > startup.sh << "EOF"
#! /bin/bash

# 获取容器IP地址
host_ip=$(ifconfig eth0 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 替换启动脚本的IP地址
sed -i "19d" apollo-configservice/scripts/startup.sh
sed -i "18a\SERVER_URL=\"http:\/\/$host_ip:\$SERVER_PORT\"" apollo-configservice/scripts/startup.sh

# 启动apollo-configservice服务
/bin/bash apollo-configservice/scripts/startup.sh
EOF
```

apollo-configservice容器启动时，会自动运行上述脚本来启动apollo-configservice服务。

#### 3. 创建supervisord.conf文件

supervisor是一种Linux的进程管理工具，apollo-configservice容器会用其管理自身的后台服务。在shell中运行以下命令，创建`supervisord.conf`文件：

```shell
cat > supervisord.conf << "EOF"
[supervisord]
nodaemon=true

[program:apollo-configservice]
command=/bin/bash startup.sh
EOF
```

#### 4. 创建Dockerfile文件

在shell中运行以下命令，创建用于制作apollo-configservice镜像的Dockerfile文件：

```shell
cat > Dockerfile << "EOF"
# 使用自建的CentOS 6.9基础镜像
FROM registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/centos:6.9

# 镜像维护者
MAINTAINER ghoulich@aliyun.com

# 拷贝apollo-configservice压缩包和启动脚本
COPY apollo-configservice-0.11.0-SNAPSHOT-github.zip /
COPY startup.sh /
COPY supervisord.conf /etc/supervisord.conf

# 安装OpenJDK和unzip
RUN yum install -y epel-release
RUN yum install -y java-1.8.0-openjdk unzip supervisor

# 解压缩apollo-configservice压缩包
RUN unzip -d apollo-configservice apollo-configservice-0.11.0-SNAPSHOT-github.zip \
    && rm -rf apollo-configservice-0.11.0-SNAPSHOT-github.zip

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 清理系统
RUN yum clean all

# 开放8080端口
EXPOSE 8080

# 创建日志目录挂载点
VOLUME ["/var/log/apollo/configservice"]

# 自启动supervisor
CMD ["/usr/bin/supervisord"]
EOF
```

上述文件有两点需要注意：

- 公开8080端口，这是apollo-configservice的默认服务端口。
- 创建日志目录的挂载点，这样便可以通过宿主机直接查看和跟踪容器的日志。

#### 5. 构建镜像

在shell中运行以下命令，创建apollo-configservice镜像：

```shell
docker build -t apollo-configservice:latest .
```

#### 6. 上传镜像

本文会将Docker镜像交给阿里云进行托管。运行以下命令，登录阿里云镜像库，然后创建镜像标签，最后推送镜像：

```shell
# 登录阿里云镜像库
docker login --username=ghoulich@aliyun.com registry.cn-hangzhou.aliyuncs.com
# 创建镜像标签
docker tag apollo-configservice:latest registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-configservice:0.11.0
# 推送镜像
docker push registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-configservice:0.11.0
```

上传成功之后，可以在阿里云的容器镜像服务控制台中看到apollo-configservice镜像，如下图所示：

[![apollo-configservice的Docker镜像](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-01_apollo-configservice-docker-image-in-aliyun.png "apollo-configservice的Docker镜像")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-01_apollo-configservice-docker-image-in-aliyun.png "apollo-configservice的Docker镜像")

#### 7. 使用方法

如果要单独部署apollo-configservice容器，那么可以使用以下命令：

```shell
docker run --detach \
           --name apollo-configservice \
           --hostname apollo-configservice \
           --env JAVA_OPTS="$JAVA_OPTS -Dapollo_profile=github -Dspring.datasource.url=jdbc:mysql://192.168.190.128:3306/ApolloConfigDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$%^" \
           --publish 8080:8080 \
           --volume /var/log/apollo/configservice:/var/log/apollo/configservice \
           registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-configservice:0.11.0
```

上述命令有几个选项需要注意：

- `--env`：通过JAVA_OPTS环境变量，将需要的JDBC配置传入容器；
- `--publish`：将容器的8080端口映射至宿主机的8080端口；
- `--volume`：将宿主机的日志目录挂载至容器。

## 三、制作apollo-adminservice镜像

#### 1. 获取压缩包

在shell中运行以下命令，创建制作apollo-adminservice镜像的专用目录：

```shell
mkdir -pv /root/Downloads/apollo-adminservice-build
```

根据《[如何编译安装Apollo服务器（单机版）](http://ghoulich.xninja.org/2018/04/24/how-to-build-and-install-apollo-in-standalone-mode/ "如何编译安装Apollo服务器（单机版）")》编译Apollo的源码，获得`apollo-adminservice-0.11.0-SNAPSHOT-github.zip`压缩包文件，然后将其放至`/root/Downloads/apollo-adminservice-build`目录。

#### 2. 创建启动脚本

在shell中运行以下命令，创建容器使用的apollo-adminservice服务的启动脚本：

```shell
cd /root/Downloads/apollo-adminservice-build
cat > startup.sh << "EOF"
#! /bin/bash

# 获取容器IP地址
host_ip=$(ifconfig eth0 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 替换启动脚本的IP地址
sed -i "19d" apollo-adminservice/scripts/startup.sh
sed -i "18a\SERVER_URL=\"http:\/\/$host_ip:\$SERVER_PORT\"" apollo-adminservice/scripts/startup.sh

# 启动apollo-adminservice服务
/bin/bash apollo-adminservice/scripts/startup.sh
EOF
```

apollo-adminservice容器启动时，会自动运行上述脚本来启动apollo-adminservice服务。

#### 3. 创建supervisord.conf文件

supervisor是一种Linux的进程管理工具，apollo-adminservice容器会用其管理自身的后台服务。在shell中运行以下命令，创建`supervisord.conf`文件：

```shell
cat > supervisord.conf << "EOF"
[supervisord]
nodaemon=true

[program:apollo-adminservice]
command=/bin/bash startup.sh
EOF
```

#### 4. 创建Dockerfile文件

在shell中运行以下命令，创建用于制作apollo-adminservice镜像的Dockerfile文件：

```shell
cat > Dockerfile << "EOF"
# 使用自建的CentOS 6.9基础镜像
FROM registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/centos:6.9

# 镜像维护者
MAINTAINER ghoulich@aliyun.com

# 拷贝apollo-adminservice压缩包和启动脚本
COPY apollo-adminservice-0.11.0-SNAPSHOT-github.zip /
COPY startup.sh /
COPY supervisord.conf /etc/supervisord.conf

# 安装OpenJDK和unzip
RUN yum install -y epel-release
RUN yum install -y java-1.8.0-openjdk unzip supervisor

# 解压缩apollo-adminservice压缩包
RUN unzip -d apollo-adminservice apollo-adminservice-0.11.0-SNAPSHOT-github.zip \
    && rm -rf apollo-adminservice-0.11.0-SNAPSHOT-github.zip

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 清理系统
RUN yum clean all

# 开放8090端口
EXPOSE 8090

# 创建日志目录挂载点
VOLUME ["/var/log/apollo/adminservice"]

# 自启动supervisor
CMD ["/usr/bin/supervisord"]
EOF
```

上述文件有两点需要注意：

- 公开8090端口，这是apollo-adminservice的默认服务端口。
- 创建日志目录的挂载点，这样便可以通过宿主机直接查看和跟踪容器的日志。

#### 5. 构建镜像

在shell中运行以下命令，创建apollo-adminservice镜像：

```shell
docker build -t apollo-adminservice:latest .
```

#### 6. 上传镜像

本文会将Docker镜像交给阿里云进行托管。运行以下命令，登录阿里云镜像库，然后创建镜像标签，最后推送镜像：

```shell
# 登录阿里云镜像库
docker login --username=ghoulich@aliyun.com registry.cn-hangzhou.aliyuncs.com
# 创建镜像标签
docker tag apollo-adminservice:latest registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-adminservice:0.11.0
# 推送镜像
docker push registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-adminservice:0.11.0
```

上传成功之后，可以在阿里云的容器镜像服务控制台中看到apollo-adminservice镜像，如下图所示：

[![apollo-adminservice的Docker镜像](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-02_apollo-adminservice-docker-image-in-aliyun.png "apollo-adminservice的Docker镜像")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-02_apollo-adminservice-docker-image-in-aliyun.png "apollo-adminservice的Docker镜像")

#### 7. 使用方法

如果要单独部署apollo-adminservice容器，那么可以使用以下命令：

```shell
docker run --detach \
           --name apollo-adminservice \
           --hostname apollo-adminservice \
           --env JAVA_OPTS="$JAVA_OPTS -Dapollo_profile=github -Dspring.datasource.url=jdbc:mysql://192.168.190.128:3306/ApolloConfigDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$%^" \
           --publish 8090:8090 \
           --volume /var/log/apollo/adminservice:/var/log/apollo/adminservice \
           registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-adminservice:0.11.0
```

上述命令有几个选项需要注意：

- `--env`：通过JAVA_OPTS环境变量，将需要的JDBC配置传入容器；
- `--publish`：将容器的8090端口映射至宿主机的8090端口；
- `--volume`：将宿主机的日志目录挂载至容器。

## 四、制作apollo-portal镜像

#### 1. 获取压缩包

在shell中运行以下命令，创建制作apollo-portal镜像的专用目录：

```shell
mkdir -pv /root/Downloads/apollo-portal-build
```

根据《[如何编译安装Apollo服务器（单机版）](http://ghoulich.xninja.org/2018/04/24/how-to-build-and-install-apollo-in-standalone-mode/ "如何编译安装Apollo服务器（单机版）")》编译Apollo的源码，获得`apollo-portal-0.11.0-SNAPSHOT-github.zip`压缩包文件，然后将其放至`/root/Downloads/apollo-portal-build`目录。

#### 2. 创建启动脚本

在shell中运行以下命令，创建容器使用的apollo-portal服务的启动脚本：

```shell
cd /root/Downloads/apollo-portal-build
cat > startup.sh << "EOF"
#! /bin/bash

# 获取容器IP地址
host_ip=$(ifconfig eth0 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 替换启动脚本的IP地址
sed -i "19d" apollo-portal/scripts/startup.sh
sed -i "18a\SERVER_URL=\"http:\/\/$host_ip:\$SERVER_PORT\"" apollo-portal/scripts/startup.sh

# 启动apollo-portal服务
/bin/bash apollo-portal/scripts/startup.sh
EOF
```

apollo-portal容器启动时，会自动运行上述脚本来启动apollo-portal服务。

#### 3. 创建supervisord.conf文件

supervisor是一种Linux的进程管理工具，apollo-portal容器会用其管理自身的后台服务。在shell中运行以下命令，创建`supervisord.conf`文件：

```shell
cat > supervisord.conf << "EOF"
[supervisord]
nodaemon=true

[program:apollo-portal]
command=/bin/bash startup.sh
EOF
```

#### 4. 创建Dockerfile文件

在shell中运行以下命令，创建用于制作apollo-portal镜像的Dockerfile文件：

```shell
cat > Dockerfile << "EOF"
# 使用自建的CentOS 6.9基础镜像
FROM registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/centos:6.9

# 镜像维护者
MAINTAINER ghoulich@aliyun.com

# 拷贝apollo-portal压缩包和启动脚本
COPY apollo-portal-0.11.0-SNAPSHOT-github.zip /
COPY startup.sh /
COPY supervisord.conf /etc/supervisord.conf

# 安装OpenJDK和unzip
RUN yum install -y epel-release
RUN yum install -y java-1.8.0-openjdk unzip supervisor

# 解压缩apollo-portal压缩包
RUN unzip -d apollo-portal apollo-portal-0.11.0-SNAPSHOT-github.zip \
    && rm -rf apollo-portal-0.11.0-SNAPSHOT-github.zip

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 清理系统
RUN yum clean all

# 开放8070端口
EXPOSE 8070

# 创建日志目录挂载点
VOLUME ["/var/log/apollo/portal"]

# 自启动supervisor
CMD ["/usr/bin/supervisord"]
EOF
```

上述文件有两点需要注意：

- 公开8070端口，这是apollo-portal的默认服务端口。
- 创建日志目录的挂载点，这样便可以通过宿主机直接查看和跟踪容器的日志。

#### 5. 构建镜像

在shell中运行以下命令，创建apollo-portal镜像：

```shell
docker build -t apollo-portal:latest .
```

#### 6. 上传镜像

本文会将Docker镜像交给阿里云进行托管。运行以下命令，登录阿里云镜像库，然后创建镜像标签，最后推送镜像：

```shell
# 登录阿里云镜像库
docker login --username=ghoulich@aliyun.com registry.cn-hangzhou.aliyuncs.com
# 创建镜像标签
docker tag apollo-portal:latest registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-portal:0.11.0
# 推送镜像
docker push registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-portal:0.11.0
```

上传成功之后，可以在阿里云的容器镜像服务控制台中看到apollo-portal镜像，如下图所示：

[![apollo-protal的Docker镜像](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-03_apollo-portal-docker-image-in-aliyun.png "apollo-protal的Docker镜像")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-03_apollo-portal-docker-image-in-aliyun.png "apollo-protal的Docker镜像")

#### 7. 使用方法

如果要单独部署apollo-portal容器，那么可以使用以下命令：

```shell
docker run --detach \
           --name apollo-portal \
           --hostname apollo-portal \
           --env JAVA_OPTS="$JAVA_OPTS -Dapollo_profile=github,auth -Ddev_meta=http://192.168.190.128:8080/ -Dserver.port=8070 -Dspring.datasource.url=jdbc:mysql://192.168.190.128:3306/ApolloPortalDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$%^" \
           --publish 8070:8070 \
           --volume /var/log/apollo/portal:/var/log/apollo/portal \
           registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-portal:0.11.0
```

上述命令有几个选项需要注意：

- `--env`：通过JAVA_OPTS环境变量，将需要的JDBC配置和Eureka服务器地址传入容器；
- `--publish`：将容器的8070端口映射至宿主机的8070端口；
- `--volume`：将宿主机的日志目录挂载至容器。

## 五、编排Apollo服务

#### 1. 创建编排专用目录

在shell中运行以下命令，创建编排Apollo服务的专用目录：

```shell
mkdir -pv /root/Downloads/apollo-compose
```

#### 2. 复制数据库初始化脚本

在shell中运行以下命令，克隆Apollo的源码库，然后复制数据库初始化脚本：

```shell
cd /root/Downloads/
git clone https://github.com/ctripcorp/apollo.git
cp apollo/scripts/sql/apolloconfigdb.sql apollo-docker/apollo-compose/
cp apollo/scripts/sql/apolloportaldb.sql apollo-docker/apollo-compose/
cd /root/Downloads/apollo-compose
```

#### 3. 创建MySQL配置文件

本文使用自建的MySQL镜像作为父镜像，制作apollo-db镜像。在shell中运行以下命令，创建`my.cnf`配置文件：

```shell
cat > my.cnf << "EOF"
# For advice on how to change settings please see
# http://dev.mysql.com/doc/refman/5.7/en/server-configuration-defaults.html

[mysqld]
#
# Remove leading # and set to the amount of RAM for the most important data
# cache in MySQL. Start at 70% of total RAM for dedicated server, else 10%.
# innodb_buffer_pool_size = 128M
#
# Remove leading # to turn on a very important data integrity option: logging
# changes to the binary log between backups.
# log_bin
#
# Remove leading # to set options mainly useful for reporting servers.
# The server defaults are faster for transactions and fast SELECTs.
# Adjust sizes as needed, experiment to find the optimal values.
# join_buffer_size = 128M
# sort_buffer_size = 2M
# read_rnd_buffer_size = 2M
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

[mysql]
default-character-set=utf8
EOF
```

注意，本文的数据库容器采用外置配置文件的方式，将`my.cnf`文件放置在宿主机中，可以简便地修改数据库配置。

#### 4. 创建apollo-db启动脚本

在shell中运行以下命令，创建apollo-db容器启动MySQL数据库的脚本文件：

```shell
cat > start.sh << "EOF"
#! /bin/bash

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

exec="/usr/bin/mysqld_safe"
prog="mysqld"

# Set timeouts here so they can be overridden from /etc/sysconfig/mysqld
STARTTIMEOUT=120

# Set in /etc/sysconfig/mysqld, will be passed to mysqld_safe
MYSQLD_OPTS=

[ -e /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

lockfile=/var/lock/subsys/$prog

# Support for extra options passed to mysqld
command=$1 && shift
extra_opts="$@"

# Extract value of a MySQL option from config files
# Usage: get_mysql_option OPTION DEFAULT SECTION1 SECTION2 SECTIONN
# Result is returned in $result
# We use my_print_defaults which prints all options from multiple files,
# with the more specific ones later; hence take the last match.
get_mysql_option () {
    option=$1
    default=$2
    shift 2
    result=$(/usr/bin/my_print_defaults "$@" | sed -n "s/^--${option}=//p" | tail -n 1)
    if [ -z "$result" ]; then
    # not found, use default
    result="${default}"
    fi
}

get_mysql_option datadir "/var/lib/mysql" mysqld
datadir="$result"
get_mysql_option socket "$datadir/mysql.sock" mysqld
socketfile="$result"
get_mysql_option log-error "/var/log/mysqld.log" mysqld mysqld_safe
errlogfile="$result"
get_mysql_option pid-file "/var/run/mysqld/mysqld.pid" mysqld mysqld_safe
mypidfile="$result"

case $socketfile in
    /*) adminsocket="$socketfile" ;;
     *) adminsocket="$datadir/$socketfile" ;;
esac

install_validate_password_sql_file () {
    local initfile
    initfile="$(mktemp /var/lib/mysql-files/install-validate-password-plugin.XXXXXX.sql)"
    chmod a+r "$initfile"
    echo "SET @@SESSION.SQL_LOG_BIN=0;" > "$initfile"
    echo "INSERT INTO mysql.plugin (name, dl) VALUES ('validate_password', 'validate_password.so');" >> "$initfile"
    echo "$initfile"
}

start(){
    [ -x $exec ] || exit 5
    # check to see if it's already running
    RESPONSE=$(/usr/bin/mysqladmin --no-defaults --socket="$adminsocket" --user=UNKNOWN_MYSQL_USER ping 2>&1)
    if [ $? = 0 ]; then
    # already running, do nothing
    action $"Starting $prog: " /bin/true
    ret=0
    elif echo "$RESPONSE" | grep -q "Access denied for user"
    then
    # already running, do nothing
    action $"Starting $prog: " /bin/true
    ret=0
    else
    # prepare for start
    if [ ! -e "$errlogfile" -a ! -h "$errlogfile" -a "x$(dirname "$errlogfile")" = "x/var/log" ]; then
        install /dev/null -m0640 -omysql -gmysql "$errlogfile"
    fi
    [ -x /sbin/restorecon ] && /sbin/restorecon "$errlogfile"
    if [ ! -d "$datadir/mysql" ] ; then
        # First, make sure $datadir is there with correct permissions
        if [ ! -d "$datadir" -a ! -h "$datadir" -a "x$(dirname "$datadir")" = "x/var/lib" ]; then
        install -d -m0751 -omysql -gmysql "$datadir" || exit 1
        fi
        if [ ! -h "$datadir" -a "x$(dirname "$datadir")" = "x/var/lib" ]; then
        chown mysql:mysql "$datadir"
        chmod 0751 "$datadir"
        fi
        if [ -x /sbin/restorecon ]; then
        /sbin/restorecon "$datadir"
        for dir in /var/lib/mysql-files /var/lib/mysql-keyring ; do
            if [ -x /usr/sbin/semanage -a -d /var/lib/mysql -a -d $dir ] ; then
            /usr/sbin/semanage fcontext -a -e /var/lib/mysql $dir >/dev/null 2>&1
            /sbin/restorecon -r $dir
            fi
        done
        fi
        # Now create the database
        initfile="$(install_validate_password_sql_file)"
        action $"Initializing MySQL database: " /usr/sbin/mysqld --initialize --datadir="$datadir" --user=mysql --init-file="$initfile"
        ret=$?
        rm -f "$initfile"
        [ $ret -ne 0 ] && return $ret
        # Generate certs if needed
        if [ -x /usr/bin/mysql_ssl_rsa_setup -a ! -e "${datadir}/server-key.pem" ] ; then
        /usr/bin/mysql_ssl_rsa_setup --datadir="$datadir" --uid=mysql >/dev/null 2>&1
        fi
    fi
    if [ ! -h "$datadir" -a "x$(dirname "$datadir")" = "x/var/lib" ]; then
        chown mysql:mysql "$datadir"
        chmod 0751 "$datadir"
    fi
    # Pass all the options determined above, to ensure consistent behavior.
    # In many cases mysqld_safe would arrive at the same conclusions anyway
    # but we need to be sure.  (An exception is that we don't force the
    # log-error setting, since this script doesn't really depend on that,
    # and some users might prefer to configure logging to syslog.)
    # Note: set --basedir to prevent probes that might trigger SELinux
    # alarms, per bug #547485
    $exec $MYSQLD_OPTS --datadir="$datadir" --socket="$socketfile" \
        --pid-file="$mypidfile" \
        --basedir=/usr --user=mysql $extra_opts >/dev/null &
    safe_pid=$!
    # Spin for a maximum of N seconds waiting for the server to come up;
    # exit the loop immediately if mysqld_safe process disappears.
    # Rather than assuming we know a valid username, accept an "access
    # denied" response as meaning the server is functioning.
    ret=0
    TIMEOUT="$STARTTIMEOUT"
    while [ $TIMEOUT -gt 0 ]; do
        RESPONSE=$(/usr/bin/mysqladmin --no-defaults --socket="$adminsocket" --user=UNKNOWN_MYSQL_USER ping 2>&1) && break
        echo "$RESPONSE" | grep -q "Access denied for user" && break
        if ! /bin/kill -0 $safe_pid 2>/dev/null; then
        echo "MySQL Daemon failed to start."
        ret=1
        break
        fi
        sleep 1
        let TIMEOUT=${TIMEOUT}-1
    done
    if [ $TIMEOUT -eq 0 ]; then
        echo "Timeout error occurred trying to start MySQL Daemon."
        ret=1
    fi
    if [ $ret -eq 0 ]; then
        action $"Starting $prog: " /bin/true
        touch $lockfile
    else
        action $"Starting $prog: " /bin/false
    fi
    fi
    return $ret
}

# 启动MySQL服务
start

# 修改初始密码
init_passwd=$(sed -rn 's/^(.*)(root@localhost: )(.*)$/\3/p' /var/log/mysqld.log)
mysql --user=root --password=${init_passwd} --connect-expired-password --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '123.Org$%^';"
mysql --user=root --password=123.Org$%^ --execute="GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '123.Org$%^' WITH GRANT OPTION;"
mysql --user=root --password=123.Org$%^ --execute="FLUSH PRIVILEGES;"

# 初始化Apollo数据库
mysql --user=root --password=123.Org$%^ < apolloportaldb.sql
mysql --user=root --password=123.Org$%^ < apolloconfigdb.sql

# 配置Eureka地址
mysql --user=root --password=123.Org$%^ --execute="UPDATE ApolloConfigDB.ServerConfig SET Value='http://${HOST_IP}:8080/eureka/' WHERE Id=1;"
EOF
```

注意，上述启动脚本改编自MySQL的服务启动脚本。当apollo-db容器启动时，首先会启动MySQL服务，然后将root用户的初始密码修改为`123.Org$%^`，然后初始化ApolloPortalDB和ApolloConfigDB数据库，最后将真实的Eureka服务器地址存入数据库。

#### 5. 创建apollo-db的Dockerfile文件

在shell中运行以下命令，创建apollo-db镜像的Dockerfile文件：

```shell
cat > Dockerfile << "EOF"
FROM registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/centos-6.9-mysql:5.7.21

MAINTAINER ghoulich@aliyun.com

COPY apolloconfigdb.sql /apolloconfigdb.sql
COPY apolloportaldb.sql /apolloportaldb.sql
COPY start.sh /start.sh
EOF
```

在进行服务编排时才会构建apollo-db镜像，不需要人为手动构建，也不会将apollo-db镜像上传至阿里云。

#### 6. 创建服务编排配置文件

在shell中运行以下命令，创建`docker-compose.yml`服务编排配置文件：

```shell
cat > docker-compose.yml << "EOF"
version: '2'

services:
  apollo-db:
    build:
      context: ./
      dockerfile: Dockerfile
    image: apollo-db:latest
    container_name: apollo-db
    hostname: apollo-db
    environment:
      TZ: Asia/Shanghai
    ports:
      - "3306:3306"
    volumes:
      - /usr/local/mysql/log/mysqld.log:/var/log/mysqld.log
      - /usr/local/mysql/config/my.cnf:/etc/my.cnf
      - /usr/local/mysql/data:/var/lib/mysql
    networks:
      apollo_network:
        ipv4_address: 172.16.238.101

  apollo-configservice:
    image: registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-configservice:0.11.0
    container_name: apollo-configservice
    hostname: apollo-configservice
    environment:
      JAVA_OPTS: "-Dapollo_profile=github -Dspring.datasource.url=jdbc:mysql://172.16.238.101:3306/ApolloConfigDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$$%^"
    depends_on:
      - apollo-db
    ports:
      - "8080:8080"
    volumes:
      - /var/log/apollo/configservice:/var/log/apollo/configservice
    networks:
      apollo_network:
        ipv4_address: 172.16.238.102

  apollo-adminservice:
    image: registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-adminservice:0.11.0
    container_name: apollo-adminservice
    hostname: apollo-adminservice
    environment:
      JAVA_OPTS: "-Dapollo_profile=github -Dspring.datasource.url=jdbc:mysql://172.16.238.101:3306/ApolloConfigDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$$%^"
    depends_on:
      - apollo-configservice
    ports:
      - "8090:8090"
    volumes:
      - /var/log/apollo/adminservice:/var/log/apollo/adminservice
    networks:
      apollo_network:
        ipv4_address: 172.16.238.103

  apollo-protal:
    image: registry.cn-hangzhou.aliyuncs.com/ghoulich-centos/apollo-portal:0.11.0
    container_name: apollo-portal
    hostname: apollo-portal
    environment:
      JAVA_OPTS: "-Dapollo_profile=github,auth -Ddev_meta=http://172.16.238.102:8080/ -Dserver.port=8070 -Dspring.datasource.url=jdbc:mysql://172.16.238.101:3306/ApolloPortalDB?characterEncoding=utf8 -Dspring.datasource.username=root -Dspring.datasource.password=123.Org$$%^"
    depends_on:
      - apollo-adminservice
    ports:
      - "8070:8070"
    volumes:
      - /var/log/apollo/portal:/var/log/apollo/portal
    networks:
      apollo_network:
        ipv4_address: 172.16.238.104

networks:
  apollo_network:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: 172.16.238.0/24
        gateway: 172.16.238.1
EOF
```

注意，`docker-compose.yml`文件定义了四个服务，分别如下所示：

##### 6.1 apollo-db

这个服务的关键配置，如下所示：

- build
在部署服务时构建apollo-db镜像，根据当前目录的Dockerfile文件进行构建。

- image
构建镜像的名称为apollo-db，标签为latest。

- ports
将容器的3306端口映射至宿主机的3306端口。

- volumes
将容器的日志、配置和数据目录挂载至宿主机。

- networks
加入名为apollo_network的网络，分配的静态IP地址为172.16.238.101。

##### 6.2 apollo-configservice

这个服务的关键配置，如下所示：

- environment
通过JAVA_OPTS环境变量，将需要的JDBC配置传入容器。

- depends_on
依赖于apollo-db容器。

- ports
将容器的8080端口映射至宿主机的8080端口。

- volumes
将容器的日志目录挂载至宿主机。

- networks
加入名为apollo_network的网络，分配的静态IP地址为172.16.238.102。

##### 6.3 apollo-adminservice

这个服务的关键配置，如下所示：

- environment
通过JAVA_OPTS环境变量，将需要的JDBC配置传入容器。

- depends_on
依赖于apollo-configservice容器。

- ports
将容器的8090端口映射至宿主机的8090端口。

- volumes
将容器的日志目录挂载至宿主机。

- networks
加入名为apollo_network的网络，分配的静态IP地址为172.16.238.103。

##### 6.4 apollo-protal

这个服务的关键配置，如下所示：

- environment
通过JAVA_OPTS环境变量，将需要的JDBC配置和Eureka服务器地址传入容器。

- depends_on
依赖于apollo-adminservice容器。

- ports
将容器的8070端口映射至宿主机的8070端口。

- volumes
将容器的日志目录挂载至宿主机。

- networks
加入名为apollo_network的网络，分配的静态IP地址为172.16.238.104。

注意，`docker-compose.yml`文件还定义了一个名为apollo_network的网络。这个网络的关键配置，如下所示：

- driver
使用桥接（bridge）网络。

- subnet
设置子网为172.16.238.0/24。

- gateway
子网的网关为172.16.238.1。

#### 7. 创建Apollo服务启动脚本

在shell中运行以下命令，创建Apollo服务启动脚本：

```shell
cat > start-apollo.sh << "EOF"
#! /bin/bash

# 创建必要的目录和文件
mkdir -p /usr/local/mysql/{data,log,config}
touch /usr/local/mysql/log/mysqld.log
cp my.cnf /usr/local/mysql/config/
chown -R 27:27 /usr/local/mysql

# 获取本机IP地址
host_ip=$(ifconfig ens33 | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

# 向docker-compose.yml添加主机IP地址
sed -i "12a\      HOST_IP: ${host_ip}" docker-compose.yml

# 启动Apollo容器集群
docker-compose up -d
EOF
```

这个脚本可以实现一键编排和部署容器化的Apollo服务。注意，第11行获取宿主机IP地址时，本文使用的网卡名为ens33，应该指定实际的网卡名称。

#### 8. 创建Apollo服务停止脚本

在shell中运行以下命令，创建Apollo服务停止脚本：

```shell
cat > shutdown-apollo.sh << "EOF"
#! /bin/bash

# 停止Apollo容器集群
docker-compose down

# 删除apollo-db镜像
docker rmi apollo-db

# 删除数据库相关目录
rm -rf /usr/local/mysql
EOF
```

注意，上述脚本会停止Apollo容器集群，然后删除本地的apollo-db镜像，最后删除Apollo服务的所有数据，使得宿主机恢复初始状态！

#### 9. 上传至GitHub

将本文涉及的所有文件都上传至GitHub或自建的GitLab，目录结构如下图所示：

[![apollo-docker的目录结构](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-04_directory-structure-of-dockerized-apollo.png "apollo-docker的目录结构")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-04_directory-structure-of-dockerized-apollo.png "apollo-docker的目录结构")

## 六、部署Apollo服务

#### 1. 克隆Apollo服务配置文件

在shell中运行以下命令，从GitHub克隆Apollo服务配置文件：

```shell
cd /root/Downloads
git clone https://github.com/ghoulich/apollo-docker.git
```

#### 2. 启动Apollo服务

在shell中运行以下命令，启动Apollo容器集群：

```shell
cd /root/Downloads/apollo-docker/apollo-compose
/bin/bash start-apollo.sh
```

请持续跟踪`/var/log/apollo`目录，查看有没有预料之外的异常。注意，服务启动时，发生Eureka连接异常是正常现象，只要不是持续不断地出现，就不必理会！

#### 3. 停止Apollo服务（可选）

如果要停止Apollo服务，将宿主机恢复成初始状态，请运行以下命令：

```shell
cd apollo-docker/apollo-compose
/bin/bash shutdown-apollo.sh
```

## 七、验证测试

#### 1. 检查容器运行状态

在shell中运行以下命令，检查Apollo容器集群的运行状态

```shell
docker ps
```

若上述命令的输出信息如下图所示，则表示Apollo各个服务组件的容器正在运行：

[![检查Apollo容器集群的运行状态](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-05_check-apollo-container-status.png "检查Apollo容器集群的运行状态")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-05_check-apollo-container-status.png "检查Apollo容器集群的运行状态")

#### 2. 检查apollo-configservice服务的健康状态

在shell中运行以下命令，调用apollo-configservice服务的health接口：

```shell
curl http://192.168.190.128:8080/health
```

若上述命令的输出信息如下图所示，则表示apollo-configservice服务运行正常：

[![检查apollo-configservice服务的健康状态](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-06_check-apollo-configservice-health-status.png "检查apollo-configservice服务的健康状态")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-06_check-apollo-configservice-health-status.png "检查apollo-configservice服务的健康状态")

#### 3. 检查apollo-adminservice服务的健康状态

在shell中运行以下命令，调用apollo-adminservice服务的health接口：

```shell
curl http://192.168.190.128:8090/health
```

若上述命令的输出信息如下图所示，则表示apollo-adminservice服务运行正常：

[![检查apollo-adminservice服务的健康状态](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-07_check-apollo-adminservice-health-status.png "检查apollo-adminservice服务的健康状态")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-07_check-apollo-adminservice-health-status.png "检查apollo-adminservice服务的健康状态")

#### 4. 检查apollo-portal服务的健康状态

在shell中运行以下命令，调用apollo-portal服务的health接口：

```shell
curl http://192.168.190.128:8070/health
```

若上述命令的输出信息如下图所示，则表示apollo-portal服务运行正常：

[![检查apollo-portal服务的健康状态](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-08_check-apollo-portal-health-status.png "检查apollo-portal服务的健康状态")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-08_check-apollo-portal-health-status.png "检查apollo-portal服务的健康状态")

#### 5. 检查Eureka服务注册状态

在Web浏览器中访问Eureka管理页面，URL如下所示：

```shell
http://192.168.190.128:8080/
```

若能够看到如下图的信息，则表示apollo-configservice和apollo-adminservice服务注册成功：

[![检查Eureka服务的注册状态](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-09_eureka-service-register-status.png "检查Eureka服务的注册状态")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-09_eureka-service-register-status.png "检查Eureka服务的注册状态")

#### 6. 登录系统

在Web浏览器中访问Apollo Portal系统，URL如下所示：

```shell
http://192.168.190.128:8070/signin
```

填写默认的用户名/密码，分别是apollo/admin。登录成功后便进入控制台首页，如下图所示：

[![Apollo后台首页](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-10_apollo-portal-index.png "Apollo后台首页")](http://ghoulich.xninja.org/wp-content/uploads/sites/2/2018/04/image-10_apollo-portal-index.png "Apollo后台首页")

至此，编排和部署容器化的Apollo服务已经全部完成了。接下来，还需要编写apollo-demo示例工程，整理Apollo的使用方法！
