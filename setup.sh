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

# Setting SELinux as permissive
echo 0 > /sys/fs/selinux/enforce

#Get outta here, IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

dnf clean all > /dev/null

echo "Turning on Fastest-Mirror"
echo "fastestmirror=true" >> /etc/dnf/dnf.conf
echo "deltarpm=false" >> /etc/dnf/dnf.conf

# Install things!

echo "Installing RPMFusion repos and some basic software!"
dnf install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y 
dnf install cabextract lzip nano p7zip p7zip-plugins unrar wget git vim sendmail xclip @development-tools -y
echo "Done with initial install!"

# Disable firewalld and enable iptables

echo "Disabling firewalld and turning on iptables!"
systemctl stop firewalld
systemctl disable firewalld
dnf install iptables-services -y
touch /etc/sysconfig/iptables
touch /etc/sysconfig/ip6tables
systemctl start iptables  
systemctl start ip6tables 
systemctl enable iptables 
systemctl enable ip6tables 
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
dnf install google-chrome-stable -y
#rpm --import https://dl-ssl.google.com/linux/linux_signing_key.pub


# Installing various programs and plugins

echo "Installing gnome-tweak, email, chat, guake, ssh-server, media stuff, and python things!"
dnf install gnome-tweak-tool thunderbird pidgin pidgin-sipe guake python-pip vlc pithos openssh-server zsh python-pandas python-beautifulsoup haveged -y
pip install pip --upgrade
pip install livestreamer
#pip install thefuck
service haveged start

# Installing Dropbox

#echo "Installing Dropbox"
#yum install libgnome dropbox -y  > /dev/null
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
#sudo ln -s $INSTALLATION_DIR/sublime_text.desktop /usr/share/applications/sublime_text.desktop
 
echo ""
echo "Sublime Text 3 installed successfully!"

cat << EOF >> /etc/ssh/sshd_config

# Disabling bad MACs and CYPHERS for sshd
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

AllowUsers $USERNAME
EOF

#Oh-My-ZSH Install (because it's amazing)
#git clone git://github.com/robbyrussell/oh-my-zsh.git /home/$USERNAME/.oh-my-zsh
#cp /home/$USERNAME/.zshrc /home/$USERNAME/.zshrc.orig
#cp /home/$USERNAME/.oh-my-zsh/templates/zshrc.zsh-template /home/$USERNAME/.zshrc
#sed -i 's/ZSH_THEME=.*$/ZSH_THEME="dallas"/g' /home/$USERNAME/.zshrc
#chsh -s /bin/zsh $USERNAME


# Start things on boot, please
chkconfig sshd on
chkconfig haveged on


rpm --rebuilddb > /dev/null
dnf install dkms -y
dnf update -y

#curl http://folkswithhats.org/fedy-installer -o fedy-installer && chmod +x fedy-installer && ./fedy-installer
