FROM centos:7

# Reset original repo
RUN rm -f /etc/yum.repos.d/*.repo && \
    echo "[base]" > /etc/yum.repos.d/CentOS-Base.repo && \
    echo "name=CentOS-7 - Base - Aliyun" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "baseurl=http://mirrors.aliyun.com/centos/7/os/x86_64/" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "[updates]" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "name=CentOS-7 - Updates - Aliyun" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "baseurl=http://mirrors.aliyun.com/centos/7/updates/x86_64/" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "[extras]" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "name=CentOS-7 - Extras - Aliyun" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "baseurl=http://mirrors.aliyun.com/centos/7/extras/x86_64/" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "" >> /etc/yum.repos.d/CentOS-Base.repo && \
    echo "[centos-sclo-rh]" > /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "name=CentOS-7 - SCLo rh - Aliyun" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "baseurl=http://mirrors.aliyun.com/centos/7/sclo/x86_64/rh/" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "[centos-sclo-sclo]" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "name=CentOS-7 - SCLo sclo - Aliyun" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "baseurl=http://mirrors.aliyun.com/centos/7/sclo/x86_64/sclo/" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-SCLo.repo && \
    yum clean all && yum makecache

# Install dev tools
RUN yum -y groupinstall "Development Tools" && \
    yum -y install centos-release-scl && \
    rm -f /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo /etc/yum.repos.d/CentOS-SCLo-scl.repo && \
    yum -y install \
        devtoolset-8 \
        wget \
        curl \
        zip \
        unzip \
        git \
        make \
        autoconf \
        automake \
        libtool \
        bzip2 \
        perl \
        python3 \
        which \
        file \
        tar \
        bash-completion \
        cups-devel \
        freetype-devel \
        alsa-lib-devel \
        libX11-devel \
        libXext-devel \
        libXrender-devel \
        libXtst-devel \
        libXt-devel \
        libXrandr-devel \
        libXi-devel \
        libXcursor-devel \
        fontconfig-devel \
        libjpeg-devel \
        libpng-devel \
        libffi-devel \
        elfutils-libelf-devel && \
    yum clean all && \
    rm -rf /var/cache/yum

SHELL ["/bin/bash", "-c"]

RUN source /opt/rh/devtoolset-8/enable && gcc --version && g++ --version

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]