FROM opensuse/tumbleweed

ENV REMOTE_BRANCH master
ENV GITHUB_REPO ceph/ceph
ENV MGR_MODULE dashboard
ENV PATH="/home/user/bin/:${PATH}"
ENV CEPH_DEV=true
ENV CEPH_BUILD_DIR=/ceph/build
ENV RGW=1
ENV CEPH_PORT=8080
ENV NVM_DIR /home/user/.nvm
ENV NODE_VERSION 10

ARG USER_UID=1000

# Update os
RUN zypper ref
RUN zypper -n dup

# Install required tools
RUN zypper -n install \
    aaa_base \
    babeltrace-devel \
    bash \
    ccache \
    curl \
    gcc \
    gcc7 \
    gcc7-c++ \
    git \
    glibc-locale \
    google-opensans-fonts \
    iproute2 \
    iputils \
    jq \
    libstdc++6-devel-gcc7 \
    lttng-ust-devel \
    man \
    neovim \
    net-tools-deprecated \
    netcat-openbsd \
    psmisc \
    python \
    python-devel \
    python3-CherryPy \
    python3-Cython \
    python3-Jinja2 \
    python3-PrettyTable \
    python3-PyJWT \
    python3-Routes \
    python3-Werkzeug \
    python3-bcrypt \
    python3-devel \
    python3-numpy \
    python3-numpy-devel \
    python3-pecan \
    python3-pip \
    python3-pyOpenSSL \
    python3-pylint \
    python3-rados \
    python3-remoto \
    python3-requests \
    python3-scipy \
    python3-yapf \
    ripgrep \
    rlwrap \
    rpm-build \
    smartmontools \
    susepaste \
    tmux \
    tox \
    vim \
    wget \
    rbd-fuse \
    zsh

RUN chsh -s /usr/bin/zsh root

RUN zypper -n install \
    python3-virtualenv python3-mypy_extensions

# SSO dependencies
RUN zypper -n install \
    libxmlsec1-1 libxmlsec1-nss1 libxmlsec1-openssl1 xmlsec1-devel \
    xmlsec1-openssl-devel
# RUN pip3 install python3-saml

RUN useradd -r -m -u ${USER_UID} user

# Install tools
RUN zypper -n install vim zsh inotify-tools wget ack sudo fzf fzf-zsh-completion && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    groupadd wheel && \
    gpasswd -a user wheel

# Install debugging tools
RUN pip3 install --upgrade pip
RUN pip3 install rpdb remote_pdb ipdb ipython

RUN python3 -m pip install --upgrade ptvsd

# Install dependencies for `api-requests.sh`
RUN pip3 install requests docopt ansicolors
# other dependencies
RUN pip3 install prettytable

# `restful` module
RUN zypper -n in python3-pyOpenSSL

# Ceph dependencies
WORKDIR /tmp
RUN wget https://raw.githubusercontent.com/${GITHUB_REPO}/${REMOTE_BRANCH}/ceph.spec.in && \
    wget https://raw.githubusercontent.com/${GITHUB_REPO}/${REMOTE_BRANCH}/install-deps.sh && \
    chmod +x install-deps.sh && \
    bash install-deps.sh && \
    zypper -n in ccache aaa_base

# CephFS
RUN zypper in -y ceph-fuse

# Frontend dependencies
RUN zypper -n in npm8 fontconfig

# Adds PyCharm debugging eggs
RUN mkdir /tmp/debug-eggs
ADD debug-eggs/ /tmp/debug-eggs

# Chrome for running E2E tests
ADD bin/install-chrome.sh /usr/local/bin/
RUN /usr/local/bin/install-chrome.sh
ENV CHROME_BIN /usr/bin/google-chrome

# User configuration
##

USER user

# Install plugin manager for neovim
RUN curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
RUN sudo mkdir -p ~/.config/nvim/plugged
RUN sudo chown -R user ~/.config/nvim/plugged

RUN git config --global core.editor nvim

ADD aliases /home/user/.aliases
ADD bashrc /home/user/.bashrc
ADD pdbrc /home/user/.pdbrc
ADD tmux.conf /home/user/.tmux.conf
# Set a nice cache size to increase the cache hit ratio alongside optimization configurations
RUN mkdir /home/user/.ccache
ADD ccache.conf /home/user/.ccache/

RUN mkdir $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use $NODE_VERSION \
    && npm install -g "@angular/cli"

RUN git clone https://github.com/robbyrussell/oh-my-zsh /home/user/.oh-my-zsh

USER root

# RUN zypper -n addrepo https://download.opensuse.org/repositories/shells:zsh-users:zsh-autosuggestions/openSUSE_Tumbleweed/shells:zsh-users:zsh-autosuggestions.repo && \
#     zypper refresh && \
#     zypper -n install zsh-autosuggestions

# Temporary fix for scipy issue in diskprection_local -> https://tracker.ceph.com/issues/43447
RUN zypper -n rm python3-scipy && pip3 install scipy==1.3.2
# Workaround for startup issues
RUN pip3 install tempora==1.8 backports.functools_lru_cache
# Fix for missing dependency in `orchestrator_cli` mgr module
RUN zypper -n in python3-PyYAML

RUN pip3 install debugpy

# User configs
USER user
ADD zshrc /home/user/.zshrc
ADD vimrc /home/user/.vimrc
ADD init.vim /home/user/.config/nvim/init.vim
ADD bin/* /usr/local/bin/

WORKDIR /ceph
