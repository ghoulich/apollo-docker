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
