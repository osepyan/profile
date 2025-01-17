#!/bin/bash
set -e

cd ~ || { echo "Home catalog not found."; exit 1; }

echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${USER}

# ----Install package----
sudo apt update && sudo apt install -y chrony fzf ripgrep gdu zsh bat curl vim mc tree net-tools bash-completion \
            dnsutils htop git iotop tmux gpg parted fonts-powerline ca-certificates apt-transport-https sysstat ncdu \
            build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

sudo apt install -y python3.12-venv  # Add Python venv installation (required by Nvim Mason for linters and formaters)

set +e
sudo apt install -y eza
sudo apt install -y exa 
sudo systemctl restart systemd-timesyncd

set -e
sudo apt autoremove

# ----Install Poetry----
curl -sSL https://install.python-poetry.org | python3 -
$HOME/.local/bin/poetry config virtualenvs.in-project true

# ----Install neovim----
if [[ ! -L /usr/local/bin/nvim ]]; then
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
sudo ln -s /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
rm nvim-linux64.tar.gz
fi

# ----Install lazygit----
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/
rm lazygit*

# ----Install lazydocker----
# allow specifying different destination directory
DIR="${DIR:-"$HOME/.local/bin"}"

# map different architecture variations to the available binaries
ARCH=$(uname -m)
case $ARCH in
    i386|i686) ARCH=x86 ;;
    armv6*) ARCH=armv6 ;;
    armv7*) ARCH=armv7 ;;
    aarch64*) ARCH=arm64 ;;
esac

# prepare the download URL
GITHUB_LATEST_VERSION=$(curl -L -s -H 'Accept: application/json' https://github.com/jesseduffield/lazydocker/releases/latest | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
GITHUB_FILE="lazydocker_${GITHUB_LATEST_VERSION//v/}_$(uname -s)_${ARCH}.tar.gz"
GITHUB_URL="https://github.com/jesseduffield/lazydocker/releases/download/${GITHUB_LATEST_VERSION}/${GITHUB_FILE}"

# install/update the local binary
curl -L -o lazydocker.tar.gz $GITHUB_URL
tar xzvf lazydocker.tar.gz lazydocker
install -Dm 755 lazydocker -t "$DIR"
rm lazydocker lazydocker.tar.gz

# ----Install tmux----
# Install and configure tmux with custom settings and TPM
if [[ -d ~/.tmux ]]; then
    # Backup existing tmux directory
    mv ~/.tmux ~/.tmux.bak
fi

# Clone the TPM repository for managing tmux plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Download the new tmux configuration file
curl https://raw.githubusercontent.com/josean-dev/dev-environment-files/main/.tmux.conf --output ~/.tmux.conf

# Ensure default terminal is set to support 256 colors
{
    echo 'set -g default-terminal "screen-256color"'
    echo 'set -g mouse on' # Enable mouse support
} >> ~/.tmux.conf

# Install plugins via TPM
~/.tmux/plugins/tpm/bin/install_plugins

#----Install bottom https://github.com/ClementTsang/bottom----
BTM_VERSION=$(curl -s "https://api.github.com/repos/ClementTsang/bottom/releases/latest" | grep  '"tag_name"' | cut -d '"' -f 4)
curl -Lo /tmp/bottom_0.10.2-1_amd64.deb "https://github.com/ClementTsang/bottom/releases/download/${BTM_VERSION}/bottom_${BTM_VERSION}-1_amd64.deb"
sudo dpkg -i /tmp/bottom_0.10.2-1_amd64.deb
rm /tmp/bottom_0.10.2-1_amd64.deb

# Delete oh-my-zsh, if exits
if [[ -d ~/.oh-my-zsh ]]; then
    rm -Rf ~/.oh-my-zsh
    echo "Removed ~/.oh-my-zsh."
else
    echo "Directory ~/.oh-my-zsh not found, continue."
fi

# ----Install oh-my-zsh----
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Clone zsh
mkdir -p ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install .zshrc
if [[ -f .zshrc ]]; then
    sed -i 's/robbyrussell/half-life/' .zshrc
    sed -i 's/^plugins=(.*)$/plugins=(z git zsh-syntax-highlighting jira zsh-autosuggestions aliases poetry)/' .zshrc
else
    echo ".zshrc not found." && exit 1
fi

# ----Install nvm----
NVM_V=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep "tag_name" | cut -d '"' -f 4)
if wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_V}/install.sh | bash; then
    echo "nvm installed."
else
    echo "Error install nvm." && exit 1
fi

# ----Install pyenv----
if curl https://pyenv.run | bash; then
    echo "pyenv installed."
else
    echo "Error install pyenv." && exit 1
fi

# ----Install my Nvim configuration----
if [[ -d ~/.config/nvim ]]; then
   mv ~/.config/nvim ~/.config/nvim.bak
   mv ~/.local/share/nvim ~/.local/share/nvim.bak
   mv ~/.local/state/nvim ~/.local/state/nvim.bak
   mv ~/.cache/nvim ~/.cache/nvim.bak
   echo "Old config NeoVim backuped."
else
   echo "Directory ~/.config/nvim not found, continue."
fi
git clone https://github.com/osepyan/nvim.git /tmp/nvim
mkdir -p ~/.config/nvim
mv /tmp/nvim/ ~/.config/
rm -rf /tmp/nvim

# ----Aliases in .zshrc----
{
    echo "export PATH=\$PATH:/usr/sbin/"
    echo "alias reload-zsh='source ~/.zshrc'"
    echo "alias edit-zsh='nvim ~/.zshrc'"
    echo "alias lg='lazygit'"
    echo "alias dt='tmux detach'"
    echo "alias lzd='lazydocker'"
    echo "alias cl='clear'"
    echo "alias nv='nvim .'"
    echo "alias sst='ss -nlptu'"
    echo "alias sss='sudo -s'"
    echo "alias less='less -F'"
    echo "alias q='exit'"
    echo "alias m='more'"
    echo "alias grep='grep --colour=always'"
    echo "alias g='grep --colour=always'"
    echo "alias tt='tail -f'"
    echo "alias getip='wget -qO- eth0.me'"
    echo "alias ls='exa'"
    echo "alias lll='ls -lha'"
    echo "alias lm='ls --long --all --sort=modified'"
    echo "alias lmm='ls -lbHigUmuSa --sort=modified --time-style=long-iso'"
    echo "alias bb='batcat -pp'"
    echo "alias bat='batcat'"
    echo "alias psc='ps xawf -eo pid,user,cgroup,args'"
    echo "alias bench='wget -qO- bench.sh | bash'"
    echo "export BAT_THEME='Monokai Extended Bright'"
    echo "export MANPAGER=\"sh -c 'col -bx | batcat -l man -p'\""
    echo "export PAGER='less -F'"
    echo "source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    echo 'export PYENV_ROOT="$HOME/.pyenv"'
    echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
    echo 'eval "$(pyenv init - zsh)"'
    echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
} >> .zshrc

# ----Change shell----
sudo chsh -s "$(which zsh)" $USER

echo "All installed."
echo "===================  !!!!!!!!!!!!   ======================="
echo "Do not forget execute 'nvm install --lts' for node js"
echo "Do not forget execute 'pyenv install 3.12 && pyenv global 3.12' for python"
