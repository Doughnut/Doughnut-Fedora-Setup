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

# Yum tweaks

cat << EOF >> /etc/yum.conf
# Disable DRPMs because they're slow

deltarpm=0
EOF

#Get outta here, IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

yum clean all > /dev/null

echo "Telling yum to keepcache!"
sed -i 's/keepcache=.*$/keepcache=1/g' "/etc/yum.conf"
echo "Installing  Yum Fastest-Mirror"
yum install yum-plugin-fastestmirror* -y  > /dev/null

# Install things!

echo "Installing RPMFusion repos and some basic software!"
yum localinstall --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y > /dev/null
yum install cabextract lzip nano p7zip p7zip-plugins unrar wget git vim sendmail xclip -y  > /dev/null
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-*
echo "Done with initial install!"

# Disable firewalld and enable iptables

echo "Disabling firewalld and turning on iptables!"
systemctl disable firewalld  > /dev/null
systemctl stop firewalld > /dev/null
yum install iptables-services -y  > /dev/null
touch /etc/sysconfig/iptables  > /dev/null
touch /etc/sysconfig/ip6tables  > /dev/null
systemctl start iptables  > /dev/null
systemctl start ip6tables > /dev/null
systemctl enable iptables > /dev/null
systemctl enable ip6tables > /dev/null
/sbin/service iptables save 

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
/sbin/service iptables save
echo "Done setting up iptables!"



# Setting SELinux as permissive

echo 0 > /selinux/enforce

selinuxfile=/etc/sysconfig/selinux
echo "Disabling SELinux"
cp $selinuxfile /etc/sysconfig/selinux_backup

cat << EOF > $selinuxfile
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
# enforcing - SELinux security policy is enforced.
# permissive - SELinux prints warnings instead of enforcing.
# disabled - SELinux is fully disabled.
SELINUX=disabled
# SELINUXTYPE= type of policy in use. Possible values are:
# targeted - Only targeted network daemons are protected.
# strict - Full SELinux protection.
SELINUXTYPE=targeted
EOF

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
yum install google-chrome-stable -y  > /dev/null
rpm --import https://dl-ssl.google.com/linux/linux_signing_key.pub


# Installing various programs and plugins

echo "Installing gnome-tweak, email, chat, guake, ssh-server, media stuff, and python things!"
yum install gnome-tweak-tool thunderbird pidgin pidgin-sipe guake python-pip vlc pithos openssh-server python-pandas python-beautifulsoup amrnb amrwb faac faad2 flac gstreamer1-libav gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer-ffmpeg gstreamer-plugins-bad-nonfree gstreamer-plugins-espeak gstreamer-plugins-fc gstreamer-plugins-ugly gstreamer-rtsp lame libdca libmad libmatroska x264 xvidcore gstreamer1-plugins-bad-free gstreamer1-plugins-base gstreamer1-plugins-good gstreamer-plugins-bad gstreamer-plugins-bad-free gstreamer-plugins-base gstreamer-plugins-good haveged -y  > /dev/null
pip install livestreamer > /dev/null
service haveged start

# Installing Dropbox

echo "Installing Dropbox"
yum install libgnome dropbox -y  > /dev/null
#dropboxurl=$(curl https://www.dropbox.com/install?os=lnx | tr ' ' '\n' | grep -o "nautilus-dropbox-[0-9].[0-9].[0-9]-[0-9].fedora.x86_64.rpm" | head -n 1 | sed -e 's/^/http:\/\/linux.dropbox.com\/packages\/fedora\//') 
#wget $dropboxurl  > /dev/null
#rpm -U *.fedora.x86_64.rpm
#rm -rf *.fedora.x86_64.rpm  > /dev/null
#yum-config-manager --save --setopt=Dropbox.skip_if_unavailable=true

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


curl -L git.io/sublimetext | sh

# Add to applications list (thanks 4ndrej)
sudo ln -s $INSTALLATION_DIR/sublime_text.desktop /usr/share/applications/sublime_text.desktop
 
echo ""
echo "Sublime Text 3 installed successfully!"

cat << EOF >> /etc/ssh/sshd_config

# Disabling bad MACs and CYPHERS for sshd
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

AllowUsers jeffreyf
EOF

chkconfig sshd on
chkconfig haveged on

rpm --rebuilddb > /dev/null
yum update kernel* selinux* -y

curl https://satya164.github.io/fedy/fedy-installer -o fedy-installer && chmod +x fedy-installer && ./fedy-installer
