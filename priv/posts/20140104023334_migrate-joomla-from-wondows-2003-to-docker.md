{
  "title": "Migrate Joomla from Windows 2003 to Docker",
  "slug": "migrate-joomla-from-windows-2003-to-docker",
  "datetime": "2014-01-04T02:33:24.939105Z"
}
---
Before continuing my series on rails deployment with docker in a PAASY environment I needed to migrate and existing Joomla 1.5 from a Windows 2003 machine to an Azure Ubuntu Linux 12.04.
---

**Migrate Apache2/PHP website to docker**

Before continuing my series on rails deployment with docker in a PAASY environment I needed to migrate and existing Joomla 1.5 from a Windows 2003 machine to an Azure Ubuntu Linux 12.04.

Nothing fancy but there is also a Rails application pointing to the same MySql db which also needs to run on the same Linux VM.

**As the Joomla app is the main company website I don’t want any problem in the Rails app to affect the main website.**

With one machine available I decided to follow the **docker** path.

Envisioned system is as follows:

  * Data only container
  * MySql container
  * Apache2 php container
  * Rails container

**Data only container**

I started with a base data-only container following the so called **container as volume pattern**. It is a bare container not even running but existing only to expose common directories to all the other containers. Its data structure is:

  * data 
  * mysql
  * www
  * rails

Here is its Dockerfile:

<pre>
FROM ubuntu:precise
MAINTAINER Thinking Code <a href="mailto:tommaso@thinkingco.de">tommaso@thinkingco.de</a>
</pre>

# Create data directories

    RUN mkdir -p /data/mysql /data/www /data/rails

# Create /data volume
  
    VOLUME [“/data”]
    CMD /bin/sh

The container can be built and started with the following commands:

<pre>
docker build -t data-store .
docker run -name my-data-store data-store true
</pre>

If you check the container status you will find it’s exited with code 0 still it can be happily used for data storage. This strange container is the holy grail of data persistence and data migration through containers.

**MySql (MariaDB) container**

As MariaDB is an easy drop in replacement for MySql and is completely open source and i tested with Joomla I opted for this solution. The container will have a single service running exposed on port 3306. Here is the Dockerfile:

<pre>
# MariaDB (https://mariadb.org/)
FROM ubuntu:precise
MAINTAINER Thinking Code <a href="http://thinkingco.de/">tommasop@thinkingco.de</a>
# Hack for initctl not being available in Ubuntu
RUN dpkg-divert –local –rename –add /sbin/initctl RUN ln -s /bin/true /sbin/initctl
RUN echo “deb http://archive.ubuntu.com/ubuntu precise main universe” &gt; /etc/apt/sources.list && \
          apt-get update && \
          apt-get upgrade -y && \
          apt-get -y -q install wget logrotate

# Ensure UTF–8

RUN apt-get update
RUN locale-gen en_US.UTF–8
ENV LANG en_US.UTF–8 ENV LC_ALL en_US.UTF–8

# Set noninteractive mode for apt-get

ENV DEBIAN_FRONTEND noninteractive

# Install MariaDB from repository.

RUN apt-get -y install python-software-properties && \
    apt-key adv –recv-keys –keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db && \
    add-apt-repository 'deb http://mirror.jmu.edu/pub/mariadb/repo/5.5/ubuntu precise main' && \
    apt-get update && \
    apt-get install -y mariadb-server

# Decouple our data from our container.

VOLUME [“/data”]

# Configure the database to use our data dir.

RUN sed -i -e 's/^datadir\s&lt;i&gt;=.&lt;/i&gt;/datadir = \/data\/mysql/' /etc/mysql/my.cnf

# Configure MariaDB to listen on any address.

RUN sed -i -e 's/^bind-address/#bind-address/' /etc/mysql/my.cnf

EXPOSE 3306

ADD start.sh /start.sh
RUN chmod +x /start.sh
ENTRYPOINT [“/start.sh”]
</pre>

The **start.sh** script is the ENTRYPOINT for each container run from the previous Dockerfile image and is responsible for actually starting MariaDB after a setup which includes the setting of a custom datadir, the migration of the existing data in the new directory and the setup of some users and passwords.

<pre>
# !/bin/bash

# Starts up MariaDB within the container.

# Stop on error

set -e

DATADIR=“/data/mysql”

/etc/init.d/mysql stop

# test if DATADIR has content

if [ ! “$(ls -A $DATADIR)” ]; then
  echo “Initializing MariaDB at $DATADIR” # Copy the data that we generated within the container to the empty DATADIR.
  cp -R /var/lib/mysql/* $DATADIR
fi

# Ensure mysql owns the DATADIR
chown -R mysql $DATADIR chown root $DATADIR/debian*.flag

# The password for ‘debian-sys-maint’@’localhost’ is auto generated.
# The database inside of DATADIR may not have been generated with this password.
# So, we need to set this for our database to be portable.

echo "Setting password for the 'debian-sys-maint'@'localhost' user" /etc/init.d/mysql start sleep 1 DB_MAINT_PASS=$(cat /etc/mysql/debian.cnf |grep -m 1 "password\s&lt;i&gt;=\s"&lt;/i&gt;| sed 's/^password\s&lt;i&gt;=\s&lt;/i&gt;//') mysql -u root -e \ "GRANT ALL PRIVILEGES ON &lt;i&gt;.&lt;/i&gt; TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DB_MAINT_PASS';"

# Create the superuser named ‘docker’.

mysql -u root -e \ “DELETE FROM mysql.user WHERE user = ‘docker’; CREATE USER ‘docker’@’localhost’ IDENTIFIED BY ‘docker’; GRANT ALL PRIVILEGES ON &lt;i&gt;.&lt;/i&gt; TO ‘docker’@’localhost’ WITH GRANT OPTION; CREATE USER ‘docker’@‘%’ IDENTIFIED BY ‘docker’; GRANT ALL PRIVILEGES ON &lt;i&gt;.&lt;/i&gt; TO ‘docker’@‘%’ WITH GRANT OPTION;” && \
 /etc/init.d/mysql stop

# Start MariaDB

echo "Starting MariaDB…" /usr/bin/mysqld_safe </pre>

Build it and run it with volumes from the **my-data-container**.

<pre>docker build -t site-db .
docker run -d -p 3306:3306 -volumes-from my-data-store -name my-site-db site-db </pre>

So up to now we have a MariaDB saving data on a /data/mysql folder shared from another container.

**Apache2 &#8211; php container**

This is the main container which will actually serve the Jommla website. This container will have two services running: **httpd and sshd**. [Supervisord][1] will be in charge of starting both services and keep them running. Dockerfile:

<pre>
FROM ubuntu:precise
MAINTAINER Thinking Code <a href="http://thinkingco.de/">tommaso@thinkingco.de</a>

# Hack for initctl not being available in Ubuntu
RUN dpkg-divert –local –rename –add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

# Install all that’s needed
RUN echo “deb http://archive.ubuntu.com/ubuntu precise main universe” &gt; /etc/apt/sources.list && \
    apt-get update && apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install mysql-client apache2 libapache2-mod-php5 pwgen python-setuptools vim-tiny php5-mysql openssh-server sudo php5-ldap unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN easy_install supervisor

# Add all config and start files
ADD ./start.sh /start.sh
ADD ./foreground.sh /etc/apache2/foreground.sh
ADD ./supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor /var/run/sshd
RUN chmod 755 /start.sh && chmod 755 /etc/apache2/foreground.sh

# Set Apache user and log
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2

VOLUME [“/data”]

# Add site to apache

ADD ./pcsnetweb /etc/apache2/sites-available/
RUN a2ensite pcsnetweb

# Set root password to access through ssh
RUN echo "root:myroootpwd” |chpasswd

# Expose web and ssh
EXPOSE 80
EXPOSE 22

CMD [“/bin/bash”, “/start.sh”]</pre>

In addition to the Dockerfile there are several files needed to set everything up: an apache virtual host file, a file to start apache in foreground and a configuration file for supervisor. Then a start file to sum everything up and all the website files. Being a Joomla migration I only have a kickstarter.php and the jpa archive to restore everything from an akeebabackup.

So here we have the relevant part of the **supervisord.conf**:

<pre>
[program:httpd]
command=/etc/apache2/foreground.sh
stopsignal=6
sshd
[program:sshd]
command=/usr/sbin/sshd -D
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
autorestart=true
</pre>

The foreground.sh:

<pre>
#!/bin/bash

read pid cmd state ppid pgrp session tty_nr tpgid rest &lt; /proc/self/stat trap “kill -TERM -$pgrp; exit” EXIT TERM KILL SIGKILL SIGTERM SIGQUIT

source /etc/apache2/envvars
apache2 -D FOREGROUND
</pre>

The start.sh:

<pre>
#!/bin/bash

if [ -d /data/www ]; then
  cp ./site-mysite.jpa /data/www/
  cp ./kickstart-core–3.8.0.zip /data/www/
fi
if [ -f /data/www/kickstart-core–3.8.0.zip ]; then
  cd /data/www && unzip kickstart-core–3.8.0.zip
  rm kickstart-core–3.8.0.zip
  cp kickstart-core–3.8.0/* .
  rm -rf kickstart-core–3.8.0
fi
chown www-data:www-data /data/www
supervisord -n
</pre>

Now build and run it:

<pre>
docker build -t web-machine .
docker run -d -name my-web-machine -p 80:80 -p 9000:22 -link my-site-db:mysql -volumes-from my-data-store web-machine </pre>

I then needed to copy the temporary beckup files into the /data/www directory which can be done finding the actual dir with the

<pre>docker inspect my-data-store | grep data</pre>

command which will give use the actual /data/www path on the host machine.

I then moved there the two needed file for restoring Joomla from an Akeeba backup: 1. a site-mysite–20131230–162721.jpa file containing all db data and files 2. kickstart-core–3.8.0.zip containing the kickstarter.php page to restore the backup

I’m doing this manually and not through a Dockerfile because it will be needed only the first time and not on every container start up.

So now we have all the db data in the my-data-store /data/mysql dir, all the website data in the my-data-store /data/www dir thus having a full backup can be achieved also with rsync on the /data dir.

We can also access the Apache2 PHP container through ssh using the host ip address on port 9000 and from inside the Apache container connect to the MariaDB through mysql client.

 [1]: http://supervisord.org/


After my [first approach][1] to easying up the many pains of Rails deployment I happened to bump into [Docker][2] for a broader PAAS project.

So my thought was: why automate only code deployment if I can automate the whole machine deployment especially with a tool like Docker that makes this task trivial and quick.

In this way it will be extremely easy to replicate a development/production environment and instead of updating code I could simply redeploy a machine.  
Not only this but it will be easier to experiment with a broader PAAS deployment.

So these will be the takeaways from this series of posts:

  1. **Configure a Rails app to be deployed on a cloud architecture (Part 1)**
  2. **Create a vagrant test machine with docker installed (Part 1)**
  3. Interactive image building vs. Dockerfiles (Part 2)
  4. Data Persistence (Part 2)
  5. Development vs. Production (Part 2)
  6. Create 7 docker containers that will host the reconfigured rails app (Part 3): 
      * Container 1: Redis Server (for session storing)
      * Container 2: Fluentd (log collection)
      * Container 3: ElasticSearch (log storage)
      * Container 4: Kibana (log analysis)
      * Container 5: PostgreSQL + PostGIS
      * Container 6: Ruby 2.1.1 Rails Puma
      * Container 7: Nginx
  7. Link the 7 containers through [Docker Links][3] (Part 3) —> intra host communication
  8. Create another vagrant test machine with docker (Part 4)
  9. Deploy PostgreSQL on this second host (Part 4)
 10. Make the app work with the second host postgres container (Part 4) —> inter host communication
 11. SCALE (Part 5) 
      * Automatic Service Discovery with [Skydns][4] and [Skydock][5]
      * Session data and Logs HA
      * Database HA

The overview seems quite interesting so let’s start.

## Configure a Rails app to be deployed on a cloud architecture

To configure the Rails app (or every other app) to be cloud deployable you need to follow the [The twelve-factor app methodology][6].  
You can use this methodology to build software-as-a-service apps that:  
- Use declarative formats for setup automation, to minimize time and cost for new developers joining the project  
- Have a clean contract with the underlying operating system, offering maximum portability between execution environments  
- Are suitable for deployment on modern cloud platforms, obviating the need for servers and systems administration  
- Minimize divergence between development and production, enabling continuous deployment for maximum agility  
- And can scale up without significant changes to tooling, architecture, or development practices.

Going through the twelve factors I found that most of the steps are already achieved through git versioning + rails YAY!!!

Nonetheless there are some points to tackle.

### Config

Rails stores configuration in config files which are not checked into revision control. This violates the principle of **strict separation of config from code**.  
Configuration must not be grouped (development, test, production) and must be independently managed for each deploy.  
It must be stored in ***environment variables***.

So what we need is a place to store env variables which won’t be committed into our git repository and a way to load it into Rails.

The [dotenv gem][7] is a wellcomed help in this task expecially in its master branch which now initializes before database ([see here][8])

The dotenv gem let you use a `.env`file to store ENV variables (you can also use a different `.env.environment` file for each environment though this will break the twelve factor app principles) 

Something like:

    S3_BUCKET=YOURS3BUCKET
    SECRET_KEY=YOURSECRETKEYGOESHERE

That you can use in your code this way:

    config.fog_directory  = ENV['S3_BUCKET']

Every time the rails app loads it will have all the variables declared in `.env` available in `ENV`!

### Processes

**Twelve-factor processes are stateless and share-nothing**

Amongst other things this means we need to store our session data either in the DB or in another kind of datastore.  
Using the db will introduce significant lag in page rendering so I want to use a faster key/value datastore.

[Memcached][9] is a very interesting and clusterable datastore but I will use **[Redis][10]** for two fundamental reasons:  
1. first and foremost because its creator is italian!  
2. faster than memcached  
3. more powerful commands  
4. no cache warmup needed  
5. useful for solving other problems (eg. queues with Resque) 

[redis-session-store][11] to the rescue!

Once installed and run a Redis server switching Rails session management to Redis is as simple as  
adding a dependency on the redis-session-store gem to your Gemfile then run bundle.

Open the session initializer `config/initializers/session_store.rb` and add the following lines:

    AppName::Application.config.session_store :redis_session_store, {
      key: 'redis_session',
      redis: {
        db: 2,
        expire_after: 120.minutes,
        key_prefix: 'appname:session:',
        host: ENV["REDIS_PORT_6379_TCP_ADDR"], # Redis host name, default is localhost
        port: ENV["REDIS_PORT_6379_TCP_PORT"]   # Redis port, default is 6379
      }
    }
    

Restart the server and you're ready to go!

### Keep development, staging, and production as similar as possible

Using Docker on Vagrant on my development machine means that my development and production environments will be identical!

### Treat logs as event streams

While rails is already configured to log `stdout` to terminal when in development mode it is not thought to route events to a standard destination for long term archiving.

[Fluentd][12] is an open source log router (written in ruby) which can used to route log streams to a permanent storing location (MongoDB or a PostgreSQL hstore to avoid inserting another piece of software in the overall architecture, or ElasticSearch to analyze log data) and which includes a robust buffering solution.

Using fluentd in a Rails 4 can be achieved through the following steps:
1. [Prepare the OS][13]
2. [Install fluentd (Debian flavor)][14]
3. Add fluent logger gem to rails app
    gem 'act-fluent-logger-rails'
    bundle
4. Configure rails to log through fluentd
  - in config/environments/production.rb
    config.log_level = :info
    config.logger = ActFluentLoggerRails::Logger
    new()
  - create a config/fluent-logger.yml file
    production:
      fluent_host:   '192.168.x.x'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'

## Create a vagrant test machine with docker installed

The [Docker guide][15] works flawlessy and deploys a vagrant image through a Dockerfile deploying docker through docker: awesome!

The Docker version actually deployed is 0.6.1 I need to upgrade to use the **links** functionality available from 0.6.5.

    sudo apt-get install curl
    # Add the Docker repository key to your local keychain
    sudo sh -c "curl https://get.docker.io/gpg | apt-key add -"
    # Add the Docker repository to your apt sources list.
    sudo sh -c "echo deb https://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
    # update your sources list
    sudo apt-get update
    # install the latest
    sudo apt-get install lxc-docker
    

DONE!

That was easy!

**This ends Part 1.**

 [1]: http://thinkingco.de/easy-peasy-deploy
 [2]: http://www.docker.io
 [3]: http://blog.docker.io/tag/links/
 [4]: https://github.com/skynetservices/skydns
 [5]: https://github.com/crosbymichael/skydock
 [6]: 12factor.net
 [7]: https://github.com/bkeepers/dotenv
 [8]: https://github.com/laserlemon/figaro/issues/70
 [9]: http://memcached.org/
 [10]: http://redis.io/
 [11]: https://github.com/roidrage/redis-session-store
 [12]: http://fluentd.org/
 [13]: http://docs.fluentd.org/articles/before-install
 [14]: http://docs.fluentd.org/articles/install-by-deb
 [15]: http://docs.docker.io/en/latest/installation/vagrant/
