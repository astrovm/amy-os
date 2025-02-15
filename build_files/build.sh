#!/usr/bin/bash
set -euo pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

# RPM packages list
declare -A RPM_PACKAGES=(
  ["fedora"]="\
    android-tools \
    aria2 \
    bleachbit \
    cmatrix \
    coolercontrol \
    croc \
    fish \
    ghostty \
    gnome-disk-utility \
    gparted \
    hack-nerd-fonts \
    htop \
    isoimagewriter \
    john \
    neovim \
    nmap \
    openrgb \
    powerline-fonts \
    qbittorrent \
    rclone \
    rustup \
    ShellCheck \
    shfmt \
    solaar \
    starship \
    thefuck \
    tor \
    torbrowser-launcher \
    torsocks \
    ubuntu-nerd-fonts \
    ubuntumono-nerd-fonts \
    virt-manager \
    virt-viewer \
    wireshark \
    yt-dlp \
    zsh-autosuggestions \
    zsh"

  ["fedora-multimedia"]="\
    HandBrake-cli \
    HandBrake-gui \
    mpv \
    vlc"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacious \
    audacious-plugins-freeworld \
    audacity-freeworld \
    telegram-desktop"

  ["docker-ce"]="\
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin"

  ["copr:gloriouseggroll/nobara-41"]="\
    lact \
    scrcpy"

  ["brave-browser"]="brave-browser"
  ["cloudflare-warp"]="cloudflare-warp"
  ["signal-desktop"]="signal-desktop"
  ["vscode"]="code"
)

log "Starting Amy OS build process"

log "Installing RPM packages"
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  if [[ $repo == copr:* ]]; then
    # Handle COPR packages
    copr_repo=${repo#copr:}
    dnf5 -y copr enable "$copr_repo"
    dnf5 -y install "${pkg_array[@]}"
    dnf5 -y copr disable "$copr_repo"
  else
    # Handle regular packages
    [[ $repo != "fedora" ]] && enable_opt="--enable-repo=$repo" || enable_opt=""
    dnf5 -y install $enable_opt "${pkg_array[@]}"
  fi
done

log "Installing Cursor GUI"
GUI_DIR="/tmp/cursor-gui"
mkdir -p "$GUI_DIR"
curl --retry 3 -Lo "$GUI_DIR/cursor.appimage" "https://downloader.cursor.sh/linux/appImage/x64"
chmod +x "$GUI_DIR/cursor.appimage"
(cd "$GUI_DIR" && ./cursor.appimage --appimage-extract)
chmod -R a+rX "$GUI_DIR/squashfs-root"
cp -r "$GUI_DIR/squashfs-root/usr/share/icons/hicolor/"* /usr/share/icons/hicolor
rm -r "$GUI_DIR/squashfs-root/usr/share/icons/hicolor"
mkdir -p /usr/share/cursor/bin
mv "$GUI_DIR/squashfs-root/"* /usr/share/cursor
install -m 0755 /usr/share/cursor/resources/app/bin/cursor /usr/share/cursor/bin/cursor
ln -s /usr/share/cursor/bin/cursor /usr/bin/cursor

log "Installing Cursor CLI"
CLI_DIR="/tmp/cursor-cli"
mkdir -p "$CLI_DIR"
curl --retry 3 -Lo "$CLI_DIR/cursor-cli.tar.gz" "https://api2.cursor.sh/updates/download-latest?os=cli-alpine-x64"
tar -xzf "$CLI_DIR/cursor-cli.tar.gz" -C "$CLI_DIR"
install -m 0755 "$CLI_DIR/cursor" /usr/share/cursor/bin/cursor-tunnel
ln -s /usr/share/cursor/bin/cursor-tunnel /usr/bin/cursor-cli

log "Enabling system services"
systemctl enable docker libvirtd

log "Disabling autostart"
rm /etc/xdg/autostart/{solaar.desktop,com.cloudflare.WarpTaskbar.desktop}
rm /etc/skel/.config/autostart/steam.desktop

log "Configuring system"
echo "import \"/usr/share/amyos/just/install-apps.just\"" >>/usr/share/ublue-os/justfile
{
  echo "eval \"\$(starship init bash)\""
  echo "eval \"\$(thefuck --alias)\""
} >>/etc/bashrc

{
  echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  echo "eval \"\$(starship init zsh)\""
  echo "eval \"\$(thefuck --alias)\""
} >>/etc/zshrc

{
  echo "starship init fish | source"
  echo "thefuck --alias | source"
} >>/etc/fish/config.fish

log "Build process completed"
