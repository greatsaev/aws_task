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

wp_install(){
    sudo chown www-data:www-data /var/www/html
    sudo curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/sbin/wp
    sudo chmod +x /usr/local/sbin/wp 
    sudo -u www-data wp core download --path=/var/www/html || true
    sudo -u www-data cp -n /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sudo -u www-data sed -i 's/database_name_here/${db_name}/' /var/www/html/wp-config.php
    sudo -u www-data sed -i 's/username_here/${db_user}/' /var/www/html/wp-config.php
    sudo -u www-data sed -i 's/password_here/${db_pass}/' /var/www/html/wp-config.php
    sudo -u www-data sed -i 's/localhost/${db_endpoint}/' /var/www/html/wp-config.php
    sudo -u www-data wp core is-installed --path=/var/www/html/ || sudo -u www-data wp core install --url=${site_url} --title="AWS HomeWork by SG" --admin_user=${admin_name} --admin_password=${admin_pass} --admin_email=${admin_email} --path='/var/www/html/' --skip-email
    sudo -u www-data wp plugin --path=/var/www/html install server-ip-memory-usage --activate
    sudo -u www-data sed -i "s|get_bloginfo( 'name' )|get_bloginfo( 'name' ) . '@' .gethostname()|g" /var/www/html/wp-includes/blocks/site-title.php
}

wp_install_check(){
    if [ ! -f /var/www/html/wp-config.php ];
	then
		wp_install
	fi
}

main(){
    pkgs_install
    mount_efs
    wp_install_check

}

main
