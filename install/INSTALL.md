# setup database

Edit the file "init.sql" and change the passwords of the three user accounts (calcms_admin, calcms_write and calcms_read).
We use different accounts for different purposes.

## run init script with root permissions

    mysql -u root -p < ./install/init.sql

## if using plesk, use

    mysql -u admin mysql -p`cat /etc/psa/.psa.shadow` < ./install/init.sql

## import database content

    mysql -u calcms_admin -p calcms < ./install/create.sql

We use different  for different purposes. 
Do not forget to use your own passwords! 

## socket connection issues

If you use a local database connection and see the error message
"could not connect to database: Can't connect to local MySQL server through socket"
the user "www-data" cannot connect to socket due to missing permissions to the socket
file /var/run/mysqld/mysqld.sock. You can either change the directory/file permissions
or use host "127.0.0.1" in bind-address at /etc/mysql/* for client and server and
additionally as hostname in config.cgi.

## Apache HTTP Server Setup

### install mod_perl

install apache2

    apt install apache2

enable prefork mode

    a2dismod mpm_event
    a2enmod mpm_prefork
    /etc/init.d/apache2 restart

install apache2 rewrite

    apt-get install libapache2-rewrite
    a2enmod rewrite

install mod_perl2

    apt install libapache2-mod-perl2 libapache2-reload-perl libapache2-request-perl
    a2enmod perl

### Apache Configuration

Copy Virtual host configuration apache2-sites/calcms.conf to /etc/conf/apache2/sites-enabled/.

* setup domain
* setup database connection
* setup directories

### install required perl modules

There are debian packages for most required perl modules.
You can install CPAN packages, if you cannot use debian packages.
For example there is no debian package for Image::Magick::Square, so you can install it by "cpan Image::Magick::Square".

apt-get install <deb-package>

#### install debian packages

    mariadb-server
    build-essentials
    imagemagick
    libapreq2-3
    libapache2-request-perl
    libapache-dbi-perl
    libauthen-sasl-perl
    libauthen-passphrase-blowfish-perl
    libcalendar-simple-perl
    libcrypt-blowfish-perl
    libcgi-pm-perl
    libcgi-session-perl
    libcgi-simple-perl
    libconfig-general-perl
    libdatetime-perl
    libdate-calc-perl
    libdate-manip-perl
    libdbi-perl
    libdbd-mysql-perl
    libemail-sender-perl
    libencode-perl
    libjson-perl
    libhtml-formattext-withlinks-andtables-perl
    libhtml-parser-perl
    libhtml-template-perl
    libhtml-template-compiled-perl
    libmime-tools-perl
    libsession-token-perl
    libtext-multimarkdown-perl
    libtext-unidecode
    libtext-wikicreole-perl
    liburi-escape-xs-perl
    perlmagick
    sox
    libsox-fmt-all

#### Install CPAN packages

    cpan <perl-package>

    Apache2::Reload
    Apache2::Request
    Apache2::Upload
    Apache::DBI
    Authen::Passphrase
    Authen::Passphrase::BlowfishCrypt
    Calendar::Simple
    CGI
    CGI::Carp
    CGI::Cookie
    CGI::Session
    CGI::Simple
    Config::General
    Data::Dumper
    Date::Calc
    Date::Manip
    DateTime
    DBD::mysql
    DBI
    Digest::MD5
    Encode::Locale
    HTML::Entities
    HTML::FormatText
    HTML::Parse
    HTML::Template::Compiled
    HTML::Template::Compiled::Plugin::XMLEscape
    Image::Magick
    Image::Magick::Square
    JSON
    ModPerl::Util
    Session::Token
    Text::Diff::FormatedHtml
    Text::Markdown
    Text::WikiCreole
    URI::Escape

#### Configuration

Copy the configuration from website/config/config.cgi.off to website/config/config.cgi.
Setup the domain and database connection.

Now you can open the web gui at http://<localhost>/programm/

To edit your radio programm open http://<localhost>/agenda/planung/
ccAdmin
shug!3Lu

# inject calcms into your website

calcms uses a copy of your web page as a template to have the same layout as your web site.
To update calcms content create a cronjob to run tools/update_page.sh

you may have to update the paths inside update_page.sh

# how-to

## update time zones

    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql -p

if using plesk, use

    mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u admin mysql -p`cat /etc/psa/.psa.shadow`

## create database schema deltas for updates

    cat  calcmsOld.sql | mysql -u root calcmsOld
    cat  calcmsNew.sql | mysql -u root calcmsNew
    mysqldiff --force --changes-for=server2 --difftype=sql calcmsOld:calcmsNew > migrate.sql
    # make sure lines with "modified_at" contain "ON UPDATE CURRENT_TIMESTAMP"
    # for example: `modified_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    cat migrate | mysql -u root calcms
    
## reset the default admin account run

    update calcms_users set pass='$2a$08$oLiwMC1vYD8ZzfjKdpTG3OBFAXbiKslWIe0w005ysdxO0kE/A/12G', salt='oLiwMC1vYD8ZzfjKdpTG3O' where name='ccAdmin';

## Image::Magick::Square

If installation of Image::Magick::Square fails, you probably need to install a recent version of Image::Magick.
