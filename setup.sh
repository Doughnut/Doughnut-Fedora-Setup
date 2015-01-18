#!/bin/sh

if [ "$EUID" -ne 0 ]
  then echo ""
  echo "Please Run As Root"
  echo ""
fi

# This script is used to do a basic setup of Fedora 21 (Workstation) for quick rollouts.
CURRENTDIR=$(pwd)
mkdir /tmp/fedorasetup/
cd /tmp/fedorasetup

# Install things!

echo "Installing RPMFusion repos and some basic software!"
yum localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
yum install cabextract lzip nano p7zip p7zip-plugins unrar wget git -y

echo "Done with initial install!"

# Yum tweaks

echo "Telling yum to keepcache!"
sed -i 's/keepcache=.*$/keepcache=1/g' "/etc/yum.conf"
echo "Installing  Yum Fastest-Mirror"
yum install yum-plugin-fastestmirror* -y

# Disable firewalld and enable iptables

echo "Disabling firewalld and turning on iptables!"
systemctl disable firewalld
systemctl stop firewalld 
yum install iptables-services -y
touch /etc/sysconfig/iptables
touch /etc/sysconfig/ip6tables
systemctl start iptables
systemctl start ip6tables
systemctl enable iptables
systemctl enable ip6tables

# Setup iptables to only allow SSH and the needs-to-start-with-syn rule

echo "Setting up iptables!"
IPT="/sbin/iptables"
$IPT --flush
$IPT --delete-chain
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -s 0.0.0.0/0 -j DROP
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A INPUT -p tcp --dport 22 -m state --state NEW -s 0.0.0.0/0 -j ACCEPT
unset $IPT
echo "Done setting up iptables!"

# Setting SELinux as permissive

selinuxfile=/etc/sysconfig/selinux
echo "Disabling SELinux"
cp $selinuxfile /etc/sysconfig/selinux_backup

cat << EOF > $selinuxfile
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
# enforcing - SELinux security policy is enforced.
# permissive - SELinux prints warnings instead of enforcing.
# disabled - SELinux is fully disabled.
SELINUX=permissive
# SELINUXTYPE= type of policy in use. Possible values are:
# targeted - Only targeted network daemons are protected.
# strict - Full SELinux protection.
SELINUXTYPE=targeted
EOF
unset $selinuxfile

# Adding chrome repo and installing chrome stable

echo "Installing Chrome!"
cat << EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome - \$basearch
baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF
yum install google-chrome-stable -y

# Installing various programs and plugins

echo "Installing gnome-tweak, email, chat, guake, ssh-server, media stuff, and python things!"
yum install gnome-tweak-tool thunderbird pidgin pidgin-sipe guake python-pip vlc pithos openssh-server python-pandas python-beautifulsoup amrnb amrwb faac faad2 flac gstreamer1-libav gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer-ffmpeg gstreamer-plugins-bad-nonfree gstreamer-plugins-espeak gstreamer-plugins-fc gstreamer-plugins-ugly gstreamer-rtsp lame libdca libmad libmatroska x264 xvidcore gstreamer1-plugins-bad-free gstreamer1-plugins-base gstreamer1-plugins-good gstreamer-plugins-bad gstreamer-plugins-bad-free gstreamer-plugins-base gstreamer-plugins-good -y
pip install livestreamer

# Installing Dropbox

yum install python-gpgme
dropboxurl=$(curl https://www.dropbox.com/install?os=lnx | tr ' ' '\n' | grep -o "nautilus-dropbox-[0-9].[0-9].[0-9]-[0-9].fedora.x86_64.rpm" | head -n 1 | sed -e 's/^/http:\/\/linux.dropbox.com\/packages\/fedora\//')
wget $dropboxurl
rpm -U *.fedora.x86_64.rpm
rm -rf *.fedora.x86_64.rpm

# Terminal Colors! (From https://github.com/satya164/fedy/blob/master/plugins/util/color_prompt.sh)

cat <<EOF | tee /etc/profile.d/color_prompt.sh > /dev/null 2>&1
if [[ ! -z \$BASH ]]; then
    if [[ \$USER = "root" ]]; then
        PS1="\[\033[33m\][\[\033[m\]\[\033[31m\]\u@\h\[\033[m\] \[\033[33m\]\W\[\033[m\]\[\033[33m\]]\[\033[m\] \$ "
    else
        PS1="\[\033[36m\][\[\033[m\]\[\033[34m\]\u@\h\[\033[m\] \[\033[32m\]\W\[\033[m\]\[\033[36m\]]\[\033[m\] \$ "
    fi
fi
EOF



# Below copied from https://gist.github.com/simonewebdesign/8507139
# Sublime Text 3 install with Package Control
#
#     www.simonewebdesign.it/install-sublime-text-3-on-linux/
#
# Run this script with:
#
#     curl -L git.io/sublimetext | sh
 
 
# Detect the architecture
UNAME=$(uname -m)
if [ "$UNAME" = 'x86_64' ]; then
  ARCHITECTURE="x64"
else
  ARCHITECTURE="x32"
fi
 
# Download the tarball, unpack and install
URL="http://c758482.r82.cf2.rackcdn.com/sublime_text_3_build_3065_$ARCHITECTURE.tar.bz2"
INSTALLATION_DIR="/opt/sublime_text"
 
curl -o $HOME/st3.tar.bz2 $URL
if tar -xf $HOME/st3.tar.bz2 --directory=$HOME; then
  sudo mv $HOME/sublime_text_3 $INSTALLATION_DIR
  sudo ln -s $INSTALLATION_DIR/sublime_text /bin/subl
fi
rm $HOME/st3.tar.bz2
 
 
# Package Control - The Sublime Text Package Manager: https://sublime.wbond.net
curl -o $HOME/Package\ Control.sublime-package https://sublime.wbond.net/Package%20Control.sublime-package
sudo mv $HOME/Package\ Control.sublime-package "$INSTALLATION_DIR/Packages/"
 
 
# Add to applications list (thanks 4ndrej)
sudo ln -s $INSTALLATION_DIR/sublime_text.desktop /usr/share/applications/sublime_text.desktop
 
echo ""
echo "Sublime Text 3 installed successfully!"