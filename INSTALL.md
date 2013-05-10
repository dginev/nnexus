# Installation and Deployment of NNexus

## The NNexus Perl library

NNexus is a Perl library requiring perl 5.10 or later.

### Prerequisites

Installing prerequisites on Debian-based systems:
```
sudo apt-get install libmojolicious-perl libdbi-perl libdbd-sqlite3-perl \
  libhtml-parser-perl liblist-moreutils-perl libtext-unidecode-perl
```
### Standard ```make``` installation

We proceed with the standard Perl installation from source:
```
perl Makefile.PL ; make ; make test
```
**NOTE:** Running perl over Makefile.PL will warn you of any missing packages you need to install, 
either via CPAN or your OS package manager.

## The NNexus Web Service

### Quick Dev Deployment
After going through the make process, in order to quickly run the server:
```
perl blib/script/nnexus daemon
```

However, Deploying through Apache or Hypnotoad would be clearly the way to go for production use.

### Production Apache Configuration

Set up virtual hosts, e.g. in
```
/etc/apache2/sites-available/nnexus 
/etc/apache2/sites-enabled/nnexus 
```

with content (please adjust to suit):

```
<VirtualHost *:80>
    ServerName nnexus.example.com 
    DocumentRoot /path/to/nnexus/install-dir-or-blib
    Header set Access-Control-Allow-Origin *

    <Perl>
      $ENV{PLACK_ENV} = 'production';
      $ENV{MOJO_HOME} = '/path/to/nnexus/install-dir-or-blib';
    </Perl>

    <Location />
      SetHandler perl-script
      PerlHandler Plack::Handler::Apache2
      PerlSetVar psgi_app /path/to/bin-or-blib-script/nnexus
    </Location>

    ErrorLog /var/log/apache2/nnexus.error.log
    LogLevel warn
    CustomLog /var/log/apache2/nnexus.access.log combined
</VirtualHost>
```

Available paths are then: `nnexus.example.com/autolink`, `nnexus.example.com/linkentry`, and `nnexus.example.com/indexentry`.
