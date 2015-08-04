# Installation instructions for cartodb machine on SURFSara HPC cloud

See https://github.com/sverhoeven/docker-cartodb for instructions how to create a docker container. We will use the same OS and very similar steps to install CartoDB on the vm at http://cartodb.e-ecology.cloudlet.sara.nl

Passwords for accounts are not here, they are kept in a seperate file.

# Installation steps

<!-- TOC depth:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [Installation instructions for cartodb machine on SURFSara HPC cloud](#installation-instructions-for-cartodb-machine-on-surfsara-hpc-cloud)
- [Installation steps](#installation-steps)
- [Create vm](#create-vm)
- [Perform installation of cartodb](#perform-installation-of-cartodb)
	- [Clean up vm](#clean-up-vm)
	- [Run docker steps](#run-docker-steps)
	- [Windshaft](#windshaft)
	- [SQL-API](#sql-api)
	- [CartoDB config files](#cartodb-config-files)
	- [Create database](#create-database)
- [Create organization](#create-organization)
- [Start bare cartodb](#start-bare-cartodb)
	- [Start cartodb web frontend services](#start-cartodb-web-frontend-services)
- [Setup nginx](#setup-nginx)
- [Create organization members](#create-organization-members)
- [Dump gps schema](#dump-gps-schema)
- [Create gps schema](#create-gps-schema)
- [Grant organization select rights on gps schema](#grant-organization-select-rights-on-gps-schema)
- [Create wiki page with usage instructions](#create-wiki-page-with-usage-instructions)
<!-- /TOC -->

# Create vm

To start we need a vm with an OS installed on it.

1. To create a disk image, use the `Create VM` wizard on http://ui.cloud.sara.nl, choose Ubuntu, 10Gb disk size and internet accessable.
2. Use vnc to setup an account
3. Stop the vm
4. Export the disk image to virdir
5. Rename the disk image to cartodb-root.qcow2
6. Create new os image
  * Name = cartodb-root
  * Persistent = Yes
  * Path = Scratch/cartodb-root.qcow2
7.  Create new datablock image for pg data
  * Name = cartodb-pgdata
  * Type = Datablock
  * Persistent = Yes
  * Source = Empty datablock
  * Size = 100000 (100Gb)
  * FS type = ext4
8.  Create a template
  * Name = cartodb
  * VCPU = 1
  * Add cartodb_root and cartodb_pgdata images using virtio as model
  * Add networks
    * internet, filter = SSH + webservice
    * e-ecology
  * Graphics type = VNC
9.  Create and start new vm
  * VM Name = cartodb
  * Select tempate = cartodb
  * Deploy # = 1

# Perform installation of cartodb

There was an old vm also called cartodb the hostname is still in cache, so use ip to ssh to it.

## Clean up vm

The wizard installed apache, cartodb will use nginx so remove apache.

    apt-get remove apache2
    apt-get autoremove

When resuming vm the date/time is out of sync

    ntpdate www.ntp.org

Upgrade OS

    apt-get update
    apt-get upgrade -y
    reboot # to use new kernel

Setup locales

    dpkg-reconfigure locales locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8

Enable firewall as we only want ssh and http ports open

    ufw allow OpenSSH
    ufw allow Apache
    ufw enable

Setup fully qualified hostname

    echo cartodb > /etc/hostname
    perl -pi -e 's/cloudvm/cartodb.e-ecology.cloudlet.sara.nl cartodb/' /etc/hosts
    hostname cartodb

Allow mail to send from server, use `Internet site` as config option

    apt-get install postfix mailutils
		perl -pi -e 's/smtpd_use_tls=yes/smtpd_use_tls=no/' /etc/postfix/main.cf
		service postfix restart

Mount the pg data disk

    sfdisk /dev/vdb
    mkfs.ext4 /dev/vdb1
		mkdir /data
		echo '/dev/vdb1 /data ext4 defaults 0 2' >> /etc/fstab
		mount -a

## Run docker steps

The steps in the Dockerfile where mostly followed, below are changes/extras.

Make copy of cartodb docker repo for config files

    cd /opt
    git clone  https://github.com/sverhoeven/docker-cartodb

Update npm to prevent deadlocks

    npm install -g npm

Instead of Ruby via rvm we do a configure/make/make install, so we don’t need to source config scripts and expand the path.

    cd /tmp
    wget http://cache.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p551.tar.bz2
    mkdir /usr/src/ruby
    tar -jxf ruby-1.9.3-p551.tar.bz2 -C /usr/src/ruby --strip-components=1
    cd /usr/src/ruby
    autoconf;./configure;make; make install

Ran ` pg_createcluster 9.3 main --start` to generate postgresql cluster config files.

Move pg_data to own partition

    service postgresql stop
    mv /var/lib/postgresql/9.3/main /data/pg_data
    perl -pi -e 's@/var/lib/postgresql/9.3/main@/data/pg_data@' /etc/postgresql/9.3/main/postgresql.conf
		service postgresql start

The cartodb repos/services are installed in /opt, instead of root so it is cleaner

## Windshaft

In /opt/Windshaft-cartodb/config/environments copy production.js.example production.js and disable configs for cartodb.com

Increase row limit so more dense tiles can be made

   perl -pi -e 's/: 65535,/: 6553500,/' /opt/Windshaft-cartodb/config/environments/production.js

Requires a cache dir

    mkdir -p /home/ubuntu/tile_assets/
    chown cartodb  /home/ubuntu/tile_assets

Logs dir must be writeable

    chown cartodb /opt/Windshaft-cartodb/logs

Windshaft upstart script (/etc/init/windshaft-cartodb.conf):

    description "Windshaft cartodb"
    start on runlevel [2345]
    stop on starting rc RUNLEVEL=[016]
    setuid cartodb
    script
      cd /opt/Windshaft-cartodb
      node app.js production
    end script

Start it

    start windshaft-cartodb

## SQL-API

Logs dir must be writeable

    chown cartodb /opt/CartoDB-SQL-API/logs

SQL-API upstart script (/etc/init/cartodb-sql-api.conf):

    description "CartoDB SQL API"
    start on runlevel [2345]
    stop on starting rc RUNLEVEL=[016]
    setuid cartodb
    script
      cd /opt/CartoDB-SQL-API
      node app.js production
    end script

Start it

    start cartodb-sql-api

## CartoDB config files

In /opt/cartodb/config setup database config

    cp database.yml.sample database.yml

Start from docker config

    cp /opt/docker-cartodb/config/app_config.yml .

Logs and uploads dir must be exist+ writeable

    mkdir /opt/cartodb/log /opt/cartodb/public/uploads; chown cartodb /opt/cartodb/log /opt/cartodb/public/uploads

Change domain from cartodb.localhost to server name

    perl -pi -e 's/cartodb\.localhost/cartodb.e-ecology.cloudlet.sara.nl/g' config/database.yml config/app_config.yml

Use our own HERE app id/code

    perl -pi -e 's/token=A7tBPacePg9Mj_zghvKt9Q&app_id=KuYppsdXZznpffJsKT24/token=hxjeEoUywhCuOgie-HtmVg&app_id=UHgSqIeEuWXmcFRQB3dv/g' config/app_config.yml

## Create database

As postgres user create a user

    createuser -s -d  -P cartodb

Enter password `$CARTODB_PG_PW`.

In /opt/cartodb change the postgres username+password to cartodb

    perl -pi -e 's/username\: postgres/username: cartodb/' config/database.yml
    perl -pi -e 's/password:/password: $ENV["CARTODB_PG_PW"]/' config/database.yml

# Create organization

Allow cartodb user to write in db/

    chown -R cartodb /opt/cartodb/db /opt/cartodb/tmp

Following commands run as cartodb in /opt/cartodb.
Create organization administrator

    RAILS_ENV=production rake cartodb:db:setup EMAIL="s.verhoeven@esciencecenter.nl" PASSWORD=$ORG_OWNER_PW SUBDOMAIN="admin4ee"

Allow unlimited number of tables for organization admin

    RAILS_ENV=production rake cartodb:db:set_unlimited_table_quota["admin4ee"]

Create ee organization with 100.

    RAILS_ENV=production rake cartodb:db:create_new_organization_with_owner ORGANIZATION_NAME="ee" USERNAME="admin4ee" ORGANIZATION_SEATS=100 ORGANIZATION_QUOTA=102400 ORGANIZATION_DISPLAY_NAME="e-ecology"

Set organization quota to 100Gb

    RAILS_ENV=production rake cartodb:db:set_organization_quota["ee",100]

# Start bare cartodb

## Start cartodb web frontend services

Make task queue less noisy

    perl -pi -e 's/VERBOSE=true/VERBOSE=false/' script/resque

resque upstart script (/etc/init/cartodb-resque.conf):

    description "CartoDB background jobs"
    start on runlevel [2345]
    stop on starting rc RUNLEVEL=[016]
    setuid cartodb
    script
      cd /opt/cartodb
      RAILS_ENV=production bundle exec script/resque
    end script

Start resque

    start cartodb-resque

Rails upstart script (/etc/init/cartodb-rails.conf):

    description "CartoDB background jobs"
    start on runlevel [2345]
    stop on starting rc RUNLEVEL=[016]
    setuid cartodb
    script
      cd /opt/cartodb
      export HOME=/home/cartodb
      RAILS_ENV=production bundle exec script/restore_redis
      RAILS_ENV=production bundle exec rails s
    end script

Start rails

    start cartodb-rails

Capture errors in rollbar.

1. Created account on https://rollbar.com
2. Add post_server_item token to config/app_config.yml as `rollbar_api_key` key.

Capture statistics with statsd

    cd /opt
    git clone https://github.com/etsy/statsd.git
    cd statsd
    npm install

Create config file (config.js)

    {
      port: 8125,
      backends: [ "./backends/console" ]
    }

Statsd upstart script (/etc/init/statsd.conf):

    description "Statsd statistics aggregator"
    start on runlevel [2345]
    stop on starting rc RUNLEVEL=[016]
    setuid nobody
    script
      cd /opt/statsd
      node stats.js config.js
    end script

Set hostname and port in config/app_conf.yml:graphite_public to localhost and 8125 resp.

# Setup nginx

Using nginx as reverse proxy for cartodb frontend + sql api service + windshaft tiling service.

Install it

    apt-get install nginx

Setup config by disabling default and adding the one from docker

    rm /etc/nginx/sites-enabled/default
    cp /opt/docker-cartodb/config/cartodb.nginx.proxy.conf /etc/nginx/sites-enabled/cartodb
    perl -pi -e 's/cartodb\.localhost/cartodb.e-ecology.cloudlet.sara.nl/g' /etc/nginx/sites-enabled/cartodb
    service nginx restart

Instead of ssl force production to work with http instead of https by making some changes to the code

    diff --git a/app/controllers/application_controller.rb b/app/controllers/application_controller.rb
    index 7eaed07..b721c4c 100644
    --- a/app/controllers/application_controller.rb
    +++ b/app/controllers/application_controller.rb
    @@ -23,7 +23,7 @@ class ApplicationController < ActionController::Base
       rescue_from RecordNotFound,   :with => :render_404

       # this disables SSL requirement in non-production environments (add "|| Rails.env.development?" for local https)
    -  unless Rails.env.production? || Rails.env.staging?
    +  unless Rails.env.staging?
         def self.ssl_required(*splat)
           false
         end
    diff --git a/config/initializers/carto_db.rb b/config/initializers/carto_db.rb
    index f6db057..df5081d 100644
    --- a/config/initializers/carto_db.rb
    +++ b/config/initializers/carto_db.rb
    @@ -178,7 +178,7 @@ module CartoDB
       end

       def self.get_domain
    -    if Rails.env.production? || Rails.env.staging?
    +    if Rails.env.staging?
    diff --git a/app/controllers/application_controller.rb b/app/controllers/application_controller.rb
    index 7eaed07..b721c4c 100644
    --- a/app/controllers/application_controller.rb
    +++ b/app/controllers/application_controller.rb
    @@ -23,7 +23,7 @@ class ApplicationController < ActionController::Base
       rescue_from RecordNotFound,   :with => :render_404

       # this disables SSL requirement in non-production environments (add "|| Rails.env.development?" for local https)
    -  unless Rails.env.production? || Rails.env.staging?
    +  unless Rails.env.staging?
         def self.ssl_required(*splat)
           false
         end
    diff --git a/config/initializers/carto_db.rb b/config/initializers/carto_db.rb
    index f6db057..df5081d 100644
    --- a/config/initializers/carto_db.rb
    +++ b/config/initializers/carto_db.rb
    @@ -178,7 +178,7 @@ module CartoDB
       end

       def self.get_domain
    -    if Rails.env.production? || Rails.env.staging?
    +    if Rails.env.staging?
           `hostname -f`.strip
         elsif Rails.env.development?
           "vizzuality#{self.session_domain}"
    @@ -188,7 +188,7 @@ module CartoDB
       end

       def self.use_https?
    -    Rails.env.production? || Rails.env.staging?
    +    Rails.env.staging?
       end

       def self.get_session_domain

# Create organization members

1. Goto http://cartodb.e-ecology.cloudlet.sara.nl
2. Login with admin4ee and $ORG_OWNER_PW
3. Goto http://cartodb.e-ecology.cloudlet.sara.nl/user/admin4ee/organization
4. Press `create new user` button

# Export and import gps schema

    mkdir -p /data/scratch
    cd /data/scratch
		git clone https://github.com/NLeSC/eEcology-CartoDB.git

Grant user@db.e-ecology.sara.nl user access to projects that need to be dumped.
Make sure user@db.e-ecology.sara.nl can connect without password

    echo “db.e-ecology.sara.nl:5432:$EE_USER:$EE_PW’ >> ~/.pgpass
    chmod go-rw .pgpass

## Create the gps schema

	  ORGANIZATION_DB=`echo "SELECT database_name FROM users u JOIN organizations o ON u.id=o.owner_id WHERE o.name='ee'" | sudo -u postgres psql -t carto_db_production`
	  psql -U postgres $ORGANIZATION_DB < gps_limited.cartodb.ddl.sql

## Create an export

    psql -U someone -h db.e-ecology.sara.nl eecology < export.psql

## Import the data

    psql -U cartodb $ORGANIZATION_DB < import.psql

# Create wiki page with usage instructions

Page created at https://public.e-cology.sara.nl/wiki/index.php/CartoDB
