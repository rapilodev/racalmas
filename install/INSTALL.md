
# setup database

## create database

    mysqladmin -u root -p create calcms

### start mysql with root permissions

    mysql -u root -p

if using plesk, use

    mysql -u admin mysql -p`cat /etc/psa/.psa.shadow`

We use different accounts for different purposes. 
Please change the passwords config after "INDENTIFIED BY" ! 

#### create admin account

    CREATE USER 'calcms_admin'@'localhost' IDENTIFIED BY 'taes9Cho';
    GRANT ALL PRIVILEGES ON calcms.* TO 'calcms_admin'@'localhost';
    GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_admin'@'localhost';

#### create editor account

    CREATE USER 'calcms_write'@'localhost' IDENTIFIED BY 'Toothok8';
    GRANT SELECT, INSERT, UPDATE, DELETE ON calcms.* TO 'calcms_write'@'localhost';
    GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_write'@'localhost';

#### create read-only account

    CREATE USER 'calcms_read'@'localhost' IDENTIFIED BY 'Ro2chiya';
    GRANT SELECT ON calcms.* TO 'calcms_read'@'localhost';
    GRANT ALL PRIVILEGES ON calcms_test.* TO 'calcms_read'@'localhost';

### import database content

    mysql -u calcms_admin -p calcms < ./install/create.sql 

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

Virtual host configuration has to be placed at /etc/conf/apache2/.
    
    # adopt your settings here
    Define domain   your-domain.org
    Define base_dir /home/calcms
    Define perl_lib /home/radio/calcms

    # Possible values include: debug, info, notice, warn, error, crit, alert, emerg.
    LogLevel info

    # limit redirection on injecting into your website
    LimitInternalRecursion 4

    # redirect HTTP to HTTPS, 
    # only needed for HTTP configuration, do not use this at HTTPS configuration(!)
    Redirect permanent /agenda/planung https://${domain}/agenda/planung

    # inject calcms into your website
    Alias /agenda        ${base_dir}/website/agenda
    Alias /programm      ${base_dir}/website/programm
    Alias /agenda_files  ${base_dir}/website/agenda_files

    <Directory ${base_dir}/website/agenda>
        AllowOverride All
        Options -Indexes +FollowSymLinks +MultiViews +ExecCGI
        Require all granted
    </Directory>

    <Directory ${base_dir}/website/programm>
        AllowOverride All
        Options -Indexes +FollowSymLinks -MultiViews -ExecCGI
        Require all granted
    
        <IfModule mod_rewrite.c>
            RewriteBase /programm
    
            RewriteEngine on
            RewriteCond  %{REQUEST_FILENAME} -f
            RewriteRule (.*) $1 [L]
            RewriteCond  %{REQUEST_FILENAME} -d
            RewriteRule (.*) $1 [L]
    
            RewriteRule ^kalender/(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2})\.html[\?]?(.*)$   /agenda/aggregate.cgi?from_date=$1&till_date=$2&$3 [L]
            RewriteRule ^kalender/(\d{4}-\d{2}-\d{2})\.html[\?]?(.*)$                       /agenda/aggregate.cgi?date=$1&$2 [L]
            RewriteRule ^sendungen/(\d{4}-\d{2}-\d{2})\.html[\?]?(.*)$                      /agenda/aggregate.cgi?date=$1&$2 [L]
            RewriteRule ^sendung/(\d+)\.html[\?]?(.*)$                                      /agenda/aggregate.cgi?event_id=$1&$2 [L]
            RewriteRule ^sendung/serie_plus/(\d+)\.html[\?]?(.*)$                           /agenda/aggregate.cgi?next_series=$1&$2 [L]
            RewriteRule ^sendung/serie_minus/(\d+)\.html[\?]?(.*)$                          /agenda/aggregate.cgi?previous_series=$1&$2 [L]
        </IfModule>
    </Directory>

    <Directory ${base_dir}/website/agenda_files>
	    AllowOverride All
	    Options -Indexes -FollowSymLinks -MultiViews -ExecCGI
	    Require all granted
    </Directory>

    <IfModule mod_perl.c>
        PerlSetEnv LC_ALL   en_US.UTF-8
        PerlSetEnv LANGUAGE en_US.UTF-8

        PerlWarn On
        PerlModule ModPerl::RegistryPrefork

        PerlModule Apache2::Reload
        PerlInitHandler Apache2::Reload
    
        # set local tmp dir
        SetEnv TMPDIR ${base_dir}/tmp/

        # set library directory
        PerlSetEnv PERL5LIB ${base_dir}/lib/calcms/
        
        # preload libraries
        PerlPostConfigRequire ${base_dir}/lib/calcms/startup.pl
    </IfModule>

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
    libencode-perl
    libjson-perl
    libhtml-formattext-withlinks-andtables-perl
    libhtml-parser-perl
    libhtml-template-perl
    libhtml-template-compiled-perl
    libmime-base64-urlsafe-perl
    libmime-lite-perl
    libsession-token-perl
    libtext-multimarkdown-perl
    libtext-wikicreole-perl
    liburi-escape-xs-perl
    perlmagick

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
    MIME::Lite
    ModPerl::Util
    Session::Token
    Text::Diff::FormatedHtml
    Text::Markdown
    Text::WikiCreole
    URI::Escape

#### Configuration

edit configuration at website/config/config.cgi

Now you can connect to web gui 

https://<localhost>/agenda/planung/
ccAdmin
shug!3Lu

If you need to reset the default admin account run

    update calcms_users set pass='$2a$08$oLiwMC1vYD8ZzfjKdpTG3OBFAXbiKslWIe0w005ysdxO0kE/A/12G', salt='oLiwMC1vYD8ZzfjKdpTG3O' where name='ccAdmin';

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
    
