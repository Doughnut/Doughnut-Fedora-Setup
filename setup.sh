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
yum install gnome-tweak-tool thunderbird pidgin pidgin-sipe guake python-pip vlc pithos openssh-server python-pandas python-beautifulsoup amrnb amrwb faac faad2 flac gstreamer1-libav gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer-ffmpeg gstreamer-plugins-bad-nonfree gstreamer-plugins-espeak gstreamer-plugins-fc gstreamer-plugins-ugly gstreamer-rtsp lame libdca libmad libmatroska x264 xvidcore gstreamer1-plugins-bad-free gstreamer1-plugins-base gstreamer1-plugins-good gstreamer-plugins-bad gstreamer-plugins-bad-free gstreamer-plugins-base gstreamer-plugins-good -y  > /dev/null
pip install livestreamer > /dev/null

# Installing Dropbox

echo "Installing Dropbox"
yum install libgnome -y  > /dev/null
dropboxurl=$(curl https://www.dropbox.com/install?os=lnx | tr ' ' '\n' | grep -o "nautilus-dropbox-[0-9].[0-9].[0-9]-[0-9].fedora.x86_64.rpm" | head -n 1 | sed -e 's/^/http:\/\/linux.dropbox.com\/packages\/fedora\//') 
wget $dropboxurl  > /dev/null
rpm -U *.fedora.x86_64.rpm
rm -rf *.fedora.x86_64.rpm  > /dev/null
yum-config-manager --save --setopt=Dropbox.skip_if_unavailable=true

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

cat << EOF >> /etc/ssh/sshd_config

# Disabling bad MACs and CYPHERS for sshd
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com
EOF

cat << EOF >> ~/.config/autostart/pidgin.desktop

[Desktop Entry]
Name=Pidgin Internet Messenger
Name[af]=Pidgin Internetboodskapper
Name[ar]=مرسال الإنترنت بِدْجِن
Name[ast]=Mensaxeru d'internet Pidgin
Name[be@latin]=Internet-kamunikatar Pidgin
Name[bn]=পিজিন ইন্টারনেট বার্তাবাহক
Name[bn_IN]=Pidgin ইন্টারনেট মেসেঞ্জার
Name[ca]=Missatger d'Internet Pidgin
Name[ca@valencia]=Missatger d'Internet Pidgin
Name[cs]=Pidgin Internet Messenger
Name[da]=Pidgin - Internetbeskeder
Name[de]=Pidgin Internet-Sofortnachrichtendienst
Name[el]=Αποστολέας μηνυμάτων διαδικτύου Pidgin
Name[en_AU]=Pidgin Internet Messenger
Name[en_GB]=Pidgin Internet Messenger
Name[eo]=Piĝin Interreta Mesaĝilo
Name[es]=Cliente de mensajería de Internet Pidgin
Name[et]=Pidgin, Interneti sõnumivahetus
Name[eu]=Pidgin Internet-Mezularia
Name[fa]=پیغام‌رسان اینترنتی پیجین
Name[fi]=Pidgin-pikaviestin
Name[fr]=Messagerie internet Pidgin
Name[ga]=Teachtaire Idirlín Pidgin
Name[gl]=Mensaxería na Internet de Pidgin
Name[gu]=Pidgin Internet Messenger
Name[he]=פידג'ין למסרים באינטרנט
Name[hi]=पिडगिन इंटरनेट मैसेंजर
Name[hu]=Pidgin üzenetküldő
Name[id]=Pesan Internet Pidgin
Name[it]=Pidgin Internet Messenger
Name[ja]=Pidgin インターネット・メッセンジャー
Name[km]=កម្មវិធី​ផ្ញើសារ​អ៊ីនធឺណិត​របស់ Pidgin
Name[kn]=ಪಿಜಿನ್ ಇಂಟರ್ನೆಟ್ ಮೆಸೆಂಜರ್
Name[ko]=Pidgin 인터넷 메신저
Name[lt]=Pidgin pokalbiai internete
Name[mai]=पिजिन इंटरनेट मेसेंजर
Name[mhr]=Pidgin писе каласымаш алмаш клиент
Name[mk]=Pidgin инстант пораки
Name[mn]=Пизин Интернет Мессенжер
Name[mr]=Pidgin इंटरनेट संदेशवाहक
Name[my_MM]=ပင်ဂျင်း အင်တာနက် မစ်ဆင်းဂျာ
Name[nb]=Pidgin Lynmeldingsklient
Name[nl]=Pidgin Internet Messenger
Name[nn]=Pidgin Internett meldingsklient
Name[or]=ପିଜିନ୍ ଇଣ୍ଟରନେଟ ସଂଦେଶବାହକ
Name[pa]=ਪਿਡਗਿਨ ਇੰਟਰਨੈਟ ਮੈਸੰਜ਼ਰ
Name[pl]=Komunikator internetowy Pidgin
Name[pt]=Mensageiro de Internet Pidgin
Name[pt_BR]=Mensageiro da Internet Pidgin
Name[ro]=Mesagerul Pidgin
Name[ru]=Клиент обмена мгновенными сообщениями Pidgin
Name[sk]=Internetový komunikátor Pidgin
Name[sl]=Spletni sel Pidgin
Name[sq]=Pidgin Internet Messenger
Name[sr]=Пиџин Интернет писмоноша
Name[sr@latin]=Pidžin Internet pismonoša
Name[sv]=Pidgin meddelandeklient
Name[ta]=Pidgin இணையத்தள மேலாளர்
Name[te]=పిడ్జిన్ ఇంటర్నెట్ మెసెంజర్
Name[tr]=Pidgin İnternet Mesajlaşma Aracı
Name[uk]=Клієнт обміну миттєвими повідомленнями Pidgin
Name[vi]=Tin Nhắn Pidgin
Name[zh_CN]=Pidgin 互联网通讯程序
Name[zh_HK]=Pidgin 網絡即時通
Name[zh_TW]=Pidgin 網路即時通
GenericName=Internet Messenger
GenericName[af]=Internetboodskapper
GenericName[ar]=مرسال إنترنت
GenericName[ast]=Mensaxeru d'enternet
GenericName[be@latin]=Internet-kamunikatar
GenericName[bg]=Бързи съобщения
GenericName[bn]=ইন্টারনেট বার্তাবাহক
GenericName[bn_IN]=ইন্টারনেট মেসেঞ্জার
GenericName[ca]=Missatger d'Internet
GenericName[ca@valencia]=Missatger d'Internet
GenericName[cs]=Internet Messenger
GenericName[da]=Internetbeskeder
GenericName[de]=Internet-Sofortnachrichtendienst
GenericName[dz]=ཨིན་ཊར་ནེཊི་འཕྲིན་སྐྱེལ་པ།
GenericName[el]=Αποστολέας μηνυμάτων διαδικτύου
GenericName[en_AU]=Internet Messenger
GenericName[en_GB]=Internet Messenger
GenericName[eo]=Interreta Mesaĝilo
GenericName[es]=Cliente de mensajería de Internet
GenericName[et]=Interneti sõnumivahetus
GenericName[eu]=Internet-Mezularia
GenericName[fa]=پیغام‌رسان اینترنتی
GenericName[fi]=Pikaviestin
GenericName[fr]=Messagerie internet
GenericName[ga]=Teachtaire Idirlín
GenericName[gl]=Mensaxería na Internet
GenericName[gu]=Internet Messenger
GenericName[he]=למסרים באינטרנט
GenericName[hi]=इंटरनेट मेसेंजर
GenericName[hu]=Azonnali üzenetküldés
GenericName[id]=Pengirim Pesan Internet
GenericName[it]=Internet Messenger
GenericName[ja]=インターネット・メッセンジャー
GenericName[km]=កម្មវិធី​ផ្ញើសារ​អ៊ីនធឺណិត
GenericName[kn]=ಇಂಟರ್ನೆಟ್ ಮೆಸ್ಸೆಂಜರ್ 
GenericName[ko]=인터넷 메신저
GenericName[ku]=Peyamnêra înternetê
GenericName[lt]=Pokalbiai internete
GenericName[mai]=इंटरनेट मेसेंजर
GenericName[mhr]=Писе каласымаш алмаш клиент
GenericName[mk]=Инстант пораки
GenericName[mn]=Интернет Мессенжер
GenericName[mr]=इंटरनेट मेसेंजर
GenericName[my_MM]=အင်တာနက် မစ်ဆင်းဂျာ -
GenericName[nb]=Lynmeldingsklient
GenericName[nl]=Internet Messenger
GenericName[nn]=Lynmeldingsklient
GenericName[or]=ଇଣ୍ଟରନେଟ ସଂଦେଶବାହାକ
GenericName[pa]=ਇੰਟਰਨੈਟ ਮੈਸੰਜ਼ਰ
GenericName[pl]=Komunikator internetowy
GenericName[ps]=د انترنت زری
GenericName[pt]=Mensageiro Internet
GenericName[pt_BR]=Mensageiro da Internet
GenericName[ro]=Mesagerie instant
GenericName[ru]=Клиент обмена мгновенными сообщениями
GenericName[si]=අන්තර්ජාල පණිවිඩකරු
GenericName[sk]=Internetový komunikátor
GenericName[sl]=Spletni sel
GenericName[sq]=Lajmsjellës Internet
GenericName[sr]=Интернет писмоноша
GenericName[sr@latin]=Internet pismonoša
GenericName[sv]=Meddelandeklient
GenericName[ta]=இணையதள தூதுவர்
GenericName[te]=ఇంటర్నెట్ మెసెంజర్
GenericName[th]=โปรแกรมข้อความด่วน
GenericName[tr]=İnternet Mesajlaşma Aracı
GenericName[uk]=Спілкування миттєвими повідомленнями
GenericName[ur]=ا نٹرنیٹ میسینجر
GenericName[vi]=Tin Nhắn
GenericName[zh_CN]=互联网通讯程序
GenericName[zh_HK]=網絡即時通
GenericName[zh_TW]=網路即時通
Comment=Chat over IM.  Supports AIM, Google Talk, Jabber/XMPP, MSN, Yahoo and more
Comment[af]=Gesels met kitsboodsappe.  Daar is ondersteuning vir AIM, Google Talk, Jabber/XMPP, MSN, Yahoo en meer
Comment[bn]=IM-এর মাধ্যমে আড্ডা দিন। যা AIM, Google Talk, Jabber/XMPP, MSN, Yahoo এবং আরও অনেক কিছু সমর্থন করে 
Comment[bn_IN]=IM-র মাধ্যমে আলাপ।  AIM, Google Talk, Jabber/XMPP, MSN, Yahoo এবং আরো অনেক সমর্থিত হয়
Comment[ca]=Xategeu amb missatgeria instantània, amb AIM, Google Talk, Jabber/XMPP, MSN, Yahoo i més
Comment[ca@valencia]=Xategeu amb missatgeria instantània, amb AIM, Google Talk, Jabber/XMPP, MSN, Yahoo i més
Comment[cs]=Chat pomocí IM. Podporuje AIM, Google Talk, Jabber/XMPP, MSN, Yahoo a další
Comment[da]=Chat over personlige beskeder.  Understøtter AIM, Google Talk, Jabber/XMPP, MSN, Yahoo og flere
Comment[de]=Chatten mit Kurznachrichten.  Unterstützt AIM, Google Talk, Jabber/XMPP, MSN, Yahoo und weitere
Comment[el]=Συζήτηση μέσω άμεσων μηνυμάτων. Υποστηρίζει AIM,Google Talk, Jabber XMPP, MSN, Yahoo και άλλα
Comment[en_AU]=Chat over IM.  Supports AIM, Google Talk, Jabber/XMPP, MSN, Yahoo and more
Comment[en_GB]=Chat over IM.  Supports AIM, Google Talk, Jabber/XMPP, MSN, Yahoo and more
Comment[es]=Chat sobre MI. Ofrece soporte para AMI, Google Talk, Jabber/XMPP, MSN, Yahoo! y más
Comment[fr]=Conversation par messages instantanés. Supporte AIM, Google Talk, Jabber/XMPP, MSN, Yahoo et d'autres
Comment[ga]=Comhrá trí TM.  Tacaíonn sé le AIM, Google Talk, Jabber/XMPP, MSN, Yahoo agus seirbhísí eile
Comment[gu]=IM પર વાતચીત. AIM, Google Talk, Jabber/XMPP, MSN, Yahoo અને વધારેને આધાર આપે છે
Comment[he]=צ'אט בעזרת הודעות-מיידיות.  תומך AIM, Google Talk, Jabber/XMPP, MSN, Yahoo ועוד
Comment[hi]=IM पर चैट.  AIM, Google Talk, Jabber/XMPP, MSN, Yahoo और कुछ और का समर्थन करता है
Comment[hu]=Azonnali üzenetküldés AIM, Google Talk, Jabber/XMPP, MSN, Yahoo és más protokollok támogatásával
Comment[it]=Chat attraverso MI. Supporta AIM, Google Talk, Jabber/XMPP, MSN, Yahoo ed altri ancora
Comment[km]=ជជែក​កំសាន្ត​តាម​ IM ។ គាំទ្រ AIM, Google Talk, Jabber/XMPP, MSN, យ៉ាហ៊ូ​ និង​​ផ្សេងៗ​ទៀត
Comment[kn]=IM ಮೂಲಕ ಮಾತುಕತೆ.  AIM, Google Talk, Jabber/XMPP, MSN, Yahoo ಹಾಗು ಇನ್ನೂ ಬಹಳಷ್ಟನ್ನು ಬೆಂಬಲಿಸುತ್ತದೆ
Comment[lt]=Bendraukite per IM.  Palaikoma AIM, Google Talk, Jabber/XMPP, MSN, Yahoo ir daug kitų
Comment[mhr]=Писе каласымаш дене тототлымвер. AIM, Google Talk, Jabber/XMPP, MSN, Yahoo да молылын эҥерта
Comment[mr]=IM वरील संभाषण. AIM, Google Talk, Jabber/XMPP, MSN, Yahoo व आणखीकरीता समर्थन पुरवतो
Comment[my_MM]=IM သုံးပြီး စကားပြောရန်။ AIM, Google Talk, Jabber/XMPP, MSN, Yahoo နှင့် အခြားကို ထောက်ပံ့ထားသည်။
Comment[nb]=Samtale over IM. Støtter AIM, Google Talk, Jabber/XMPP, MSN, Yahoo! og mer
Comment[nl]=Chat over IM. Ondersteunt AIM, Google Talk, Jabber/XMPP, MSN, Yahoo en meer
Comment[nn]=Prat ved hjelp av lynmeldingar.  Støttar AIM, Google Talk, Jabber/XMPP, MSN, Yahoo og fleire
Comment[or]=IM ଉପରେ ଚାର୍ଟ।  AIM, Google Talk, Jabber/XMPP, MSN, Yahoo ଏବଂ ସେହିପରି ଅନେକକୁ ସମର୍ଥନ କରିଥାଏ
Comment[pa]=IM ਰਾਹੀਂ ਗੱਲਬਾਤ। AIM, ਗੂਗਲ ਟਾਕ, ਜੱਬਰ/XMPP, MSN, ਯਾਹੂ ਅਤੇ ਹੋਰ ਲਈ ਸਹਾਇਕ।
Comment[pl]=Rozmawianie przez komunikator. Obsługuje sieci AIM, Google Talk, Jabber/XMPP, MSN, Yahoo oraz więcej
Comment[pt]=Cliente de mensagens instantâneas. Suporta AIM, Google Talk, Jabber/XMPP, MSN, Yahoo!, e mais
Comment[pt_BR]=Bate-papos instantâneos.  Suporta AIM, Google Talk, Jabber/XMPP, MSN, Yahoo e outros
Comment[ro]=Chat prin mesaje instant. Suportă rețelele AIM, Google Talk, Jabber/XMPP, MSN, Yahoo și altele.
Comment[ru]=Переписка мгновенными сообщениями.  Поддерживает AIM, Google Talk, Jabber/XMPP, MSN, Yahoo и не только
Comment[sk]=Chat cez IM.  Podporuje AIM, Google Talk, Jabber/XMPP, MSN, Yahoo a ďalšie
Comment[sl]=Klepetajte s svetom. Podpira AIM, Google Talk, Jabber/XMPP, MSN, Yahoo in druge.
Comment[sq]=Fjalosje përmes IM-së.  Mbulon AIM, Google Talk, Jabber/XMPP, MSN, Yahoo dhe të tjera
Comment[sv]=Skicka snabbmeddelanden.  Stödjer AIM, Google Talk, Jabber/XMPP, MSN, Yahoo med fler
Comment[ta]=அரட்டை IM முடிந்தது.  AIMக்கு துணைபுரிகிறது, Google Talk, Jabber/XMPP, MSN, Yahoo மற்றும் மேலும்
Comment[te]=IM నందు చాట్.  AIM, Google Talk, Jabber/XMPP, MSN, Yahoo మరియు మరిన్ని మద్దతిస్తుంది
Comment[uk]=Балачка через миттєві повідомлення. Підтримує AIM, Google Talk, Jabber/XMPP, MSN, Yahoo та інші
Comment[vi]=Trò chuyện qua mạng tin nhắn tức khắc: hỗ trợ AIM, Google Talk, Jabber/XMPP, MSN, Yahoo và nhiều mạng khác
Comment[zh_CN]=互联网通讯程序。 支持 AIM、Google Talk、Jabber/XMPP、MSN、Yahoo 和更多
Comment[zh_HK]=讓你可以透過即時通訊與好友聊天，支援 AIM、Google Talk、Jabber/XMPP、MSN、Yahoo 等等
Comment[zh_TW]=讓您可以透過即時通訊與好友聊天，支援 AIM、Google Talk、Jabber/XMPP、MSN、Yahoo 等等
Exec=pidgin 
Icon=pidgin
StartupNotify=true
Terminal=false
Type=Application
Categories=Network;InstantMessaging;X-Red-Hat-Base;

X-Desktop-File-Install-Version=0.22

EOF


cat << EOF > ~/.config/autostart/guake.desktop

[Desktop Entry]
Encoding=UTF-8
Name=Guake Terminal
Name[pt]=Guake Terminal
Name[pt_BR]=Guake Terminal
Name[fr]=Guake Terminal
Name[fr_FR]=Guake Terminal
Comment=Use the command line in a Quake-like terminal
Comment[pt]=Utilizar a linha de comando em um terminal estilo Quake
Comment[pt_BR]=Utilizar a linha de comando em um terminal estilo Quake
Comment[fr]=Utilisez la ligne de commande comme dans un terminal quake
Comment[fr_FR]=Utilisez la ligne de commande comme dans un terminal quake
TryExec=guake
Exec=guake
Icon=guake
Type=Application
Categories=GNOME;GTK;System;Utility;TerminalEmulator;
StartupNotify=true
Keywords=Terminal;Utility;
X-Desktop-File-Install-Version=0.22

EOF

cat << EOF > ~/.config/gconf/apps/guake/general/%gconf.xml

<?xml version="1.0"?>
<gconf>
        <entry name="window_height_f" mtime="1427894872" type="float" value="100"/>
        <entry name="window_height" mtime="1427894872" type="int" value="100"/>
        <entry name="compat_delete" mtime="1427894868" type="string">
                <stringvalue>delete-sequence</stringvalue>
        </entry>
        <entry name="compat_backspace" mtime="1427894868" type="string">
                <stringvalue>ascii-delete</stringvalue>
        </entry>
        <entry name="use_default_font" mtime="1427894868" type="bool" value="true"/>
        <entry name="scroll_keystroke" mtime="1427894868" type="bool" value="true"/>
        <entry name="history_size" mtime="1427894883" type="int" value="8192"/>
        <entry name="use_scrollbar" mtime="1427894877" type="bool" value="false"/>
        <entry name="mouse_display" mtime="1427894869" type="bool" value="false"/>
        <entry name="display_n" mtime="1427894871" type="int" value="2"/>
        <entry name="quick_open_command_line" mtime="1427894868" type="string">
                <stringvalue>gedit %(file_path)s</stringvalue>
        </entry>
        <entry name="window_tabbar" mtime="1427894868" type="bool" value="true"/>
        <entry name="window_halignment" mtime="1427894868" type="int" value="0"/>
        <entry name="window_width_f" mtime="1427894868" type="float" value="100"/>
        <entry name="window_width" mtime="1427894868" type="int" value="100"/>
        <entry name="window_losefocus" mtime="1427894868" type="bool" value="false"/>
        <entry name="prompt_on_quit" mtime="1427894868" type="bool" value="true"/>
        <entry name="use_popup" mtime="1427894874" type="bool" value="false"/>
        <entry name="use_trayicon" mtime="1427894868" type="bool" value="true"/>
</gconf>

EOF

cat << EOF > ~/.config/gconf/apps/guake/keybindings/local/%gconf.xml

<?xml version="1.0"?>
<gconf>
        <entry name="next_tab" mtime="1427894888" type="string">
                <stringvalue>&lt;Primary&gt;1</stringvalue>
        </entry>
        <entry name="previous_tab" mtime="1427894887" type="string">
                <stringvalue>&lt;Primary&gt;grave</stringvalue>
        </entry>
</gconf>

EOF

rpm --rebuilddb > /dev/null
yum update kernel* selinux* -y

curl https://satya164.github.io/fedy/fedy-installer -o fedy-installer && chmod +x fedy-installer && ./fedy-installer
