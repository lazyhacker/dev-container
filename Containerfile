# Start with the latest Fedora
FROM fedora:latest

# Ensure the container environment defaults to UTF-8
#ENV LANG=en_US.UTF-8

# 1. Install system dependencies + tmux + git + vim
RUN dnf -y update && dnf -y install \
    curl tar gzip git gcc glibc-devel make tmux vim-enhanced jq \
    powerline-fonts \
    && dnf clean all

# 2. Download and install Go 1.26.1
ARG GO_VERSION=1.26.1
RUN curl -OL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# 3. Dynamic User Setup (Arguments passed by dev-start.sh)
ARG USER_NAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USER_NAME

# 4. Set Environment Variables
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/${USER_NAME}/go
ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Switch to the new user context
USER $USER_NAME
WORKDIR /home/$USER_NAME

# --- CACHE BUSTER ---
# The script passes a timestamp here to force a fresh clone of everything below
ARG CACHEBUST=1

# 6. Clone and Install Dotfiles
RUN rm -rf /home/$USER_NAME/dotfiles && \
    git clone https://github.com/lazyhacker/dotfiles.git /home/$USER_NAME/dotfiles && \
    cd /home/$USER_NAME/dotfiles && \
    if [ -f ./install.sh ]; then \
        chmod +x ./install.sh && ./install.sh; \
    fi

# 5. Setup Vim Plugin Manager (Vundle)
# Atomic: Delete and Re-clone in one layer
RUN rm -rf /home/$USER_NAME/.vim/bundle/Vundle.vim && \
    mkdir -p /home/$USER_NAME/.vim/bundle && \
    git clone https://github.com/VundleVim/Vundle.vim.git /home/$USER_NAME/.vim/bundle/Vundle.vim

# 7. Install Vim Plugins via Vundle (Silent/Non-interactive)
# We use -T dumb to avoid terminal errors and 'silent!' to ignore 
# missing colorscheme errors that happen before the plugins are installed.
RUN vim -u /home/${USER_NAME}/.vimrc -T dumb -n -i NONE -es \
    -c "silent! PluginInstall" \
    -c "qall" || true

WORKDIR /home/$USER_NAME/project
CMD ["sleep", "infinity"]
