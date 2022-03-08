#!/bin/bash

pkgs_install(){
    sudo apt update
    sudo apt-get install -y nfs-common apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip
}

mount_efs(){
    sudo mkdir -p /var/www/html
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_mount_dns}:/ /var/www/html
    cat <<EOF >>/etc/fstab
${efs_mount_dns}:/   /var/www/html   nfs4    nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0
EOF
}



main(){
    pkgs_install
    mount_efs

}

main
