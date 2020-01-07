{
  "title": "Deployment Rails with Docker Part 2",
  "slug": "deployment-rails-with-docker-part-2",
  "datetime": "2014-01-04T02:33:24.939105Z"
}
---
Second part of deploy rails with Docker.
---

Series takeaways:

  1.  Configure a Rails app to be deployed on a cloud architecture (Part 1)
  2.  Create a vagrant test machine with docker installed (Part 1)
  3.  **Interactive image building vs. Dockerfiles (Part 2)**
  4.  **Data Persistence (Part 2)**
  5.  **Good Practices (Part 2)**
  6.  Create 7 docker containers that will host the reconfigured rails app (Part 3):
    *   Container 1: Redis Server (for session storing)
    *   Container 2: Fluentd (log collection)
    *   Container 3: ElasticSearch (log storage)
    *   Container 4: Kibana (log analysis)
    *   Container 5: PostgreSQL + PostGIS
    *   Container 6: Chruby Ruby Rails Puma
    *   Container 7: Nginx
  7.  Link the 7 containers through [Docker Links](http://blog.docker.io/tag/links/) (Part 3) intra host communication
  8.  Real Docker Playground with two hosts (Part 4)
  9.  Deploy PostgreSQL on this second host (Part 4)
  10.  Make the app work with the second host postgres container (Part 4) inter host communication
  11.  SCALE (Part 5)
    *   Automatic Service Discovery with [Skydns](https://github.com/skynetservices/skydns) and [Skydock](https://github.com/crosbymichael/skydock)
    *   Session data and Logs HA
    *   Database HA

## Interactive image building vs Dockerfiles

  It is possible to create docker images either interactively or through a Dockerfile.

  To clarify this I'll show how to create a Redis Server in both ways.

### Container 1: Redis Server

  We need to login into the vagrant machine to begin working with our containers

  `
  <pre><pre class="brush: bash; title: ; notranslate" title="">vagrant ssh</pre>

#### Manual build process

  Using the vagrant docker image docker will already be running in daemon mode.

  To run a container from the base ubuntu image:

  <pre><pre class="brush: bash; title: ; notranslate" title="">sudo docker run -i -t ubuntu /bin/bash</pre>

  This will run a container in interactive (-i) mode with a pseudo tty (-t) and give us a /bin/bash terminal to use inside the container.
  The container will be spawned from an image, the base ubuntu image which will be automatically downloaded if not found locally.

  The command will give us access to the newly spawned container as root.

  We will then be able to issue all the needed commands to setup the desired service in the following example the redis server:

  <pre><pre class="brush: bash; title: ; notranslate" title="">&lt;br /&gt;&lt;%%KEEPWHITESPACE%%&gt; echo &quot;deb http://archive.ubuntu.com/ubuntu precise main universe&quot; &amp;gt; /etc/apt/sources.list&lt;br /&gt;&lt;%%KEEPWHITESPACE%%&gt; apt-get update&lt;br /&gt;&lt;%%KEEPWHITESPACE%%&gt; apt-get install -y redis-server&lt;br /&gt;</pre>

  The base redis machine is ready let‚Äôs commit it and save it as an image to be able to spawn it multiple times as needed.

  Send ctrl-p + ctrl-q to exit the container shell (if you forgot something just `sudo docker attach <container_id>`) and then run:

  <pre><pre class="brush: bash; title: ; notranslate" title="">sudo docker commit &amp;lt;container_id&amp;gt; &amp;lt;some_name&amp;gt;</pre>

  If you simply `exit` the container shell the container will shut down.

#### Dockerfile

  The docker build process of a Dockerfile has the following logical steps:

1.  spawn a container from an image (because images are immutable)
  2.  run shell scripts inside the container
  3.  save the result: commit the container as an intermediate image
  4.  proceed to next build step

  A `Dockerfile` is a shell inspired script supporting [few instructions](http://docs.docker.io/en/latest/use/builder/) that describes the `docker build` process.

  Here is the same redis server machine expressed with a Dockerfile:

  <pre><pre class="brush: bash; title: ; notranslate" title="">&lt;br /&gt;FROM ubuntu:precise&lt;br /&gt;RUN apt-get update&lt;br /&gt;RUN apt-get -y install redis-server&lt;br /&gt;EXPOSE 6379&lt;br /&gt;ENTRYPOINT [&quot;/usr/bin/redis-server&quot;]</pre>

  You can also leverage the wonderful docker community and pull a ready-to-go image from the Docker index:

  <pre><pre class="brush: bash; title: ; notranslate" title="">docker pull dockerfile/redis</pre>

## Data Persistence

  As **containers are ephemeral** two problems arises:

  1.  **Data Persistence** across containers restart
  2.  **Network configuration persistence or predictability** across containers restart

  I‚Äôll deal here about the first issue and in _Part 4_ about the latter.

  Data persistence can be implemented in Docker essentially in three ways:

  1.  Sharing a volume between a container and the host
  2.  Decoupling data within each container creating a volume
  3.  Sharing one or more containers as the data volume hoders between one or more containers

  The first and second implementations are as easy as:

  <pre><pre class="brush: bash; title: ; notranslate" title="">sudo docker run -v /var/logs:/var/host_logs:ro ubuntu bash</pre>
  <pre class="brush: bash; title: ; notranslate" title="">sudo docker run -v /var/new_volume ubuntu bash</pre>

  with the `-v` option taking the following parameters:

  <pre><pre class="brush: bash; title: ; notranslate" title="">-v=[]: Create a bind mount with: [host-dir]:[container-dir]:[rw|ro].&lt;br /&gt;If &quot;host-dir&quot; is missing, then docker creates a new volume.</pre>

  The Docker documentation explains very well why sharing volumes with the host is not good:

  **This is not available from a Dockerfile as it makes the built image less portable or shareable. [host-dir] volumes are 100% host dependent and will break on any other machine.**

  To obtain **data decouplication** you can also add a `VOLUME`directive to an image Dockerfile and this will automatically create a new volume.
  Data in the volume is not destroyed with the container but will persist in a `/var/lib/docker/dir/vfs/container_id` folder that you can grabo with a `docker inspect`.

  The third implementation is almost easy as the first two but has the portability/shareability advantage we need. It is a **data decouplication** run through an intermediate container. A sort of _container-in-the-middle_ that while persisting data can also be easily ported to another host.

  You can create a data container like this:

  <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -v /data/www -v /data/db busybox true</pre>

  or

  <pre><pre class="brush: bash; title: ; notranslate" title="">&lt;/pre&gt;&lt;h1&gt;BUILD-USING: docker build -t data .&lt;/h1&gt;&lt;h1&gt;RUN-USING: docker run -name DATA data&lt;/h1&gt;&lt;pre&gt;&lt;br /&gt;FROM busybox&lt;br /&gt;VOLUME [‚Äú/data/www‚Äù, ‚Äú/data/db‚Äù]&lt;br /&gt;CMD [&quot;true&quot;]</pre>

  As any container needs a command to run, `true` is the smallest, simplest program that you can run. Running the true command will immediately exit the container but **once created you can mount its volumes in any other container using the `-volumes-from` option; irrespecive of whether the container is running or not.**

  **busybox** is a wonderful linux image ASACB (as small as can be) ~ 2.5 MB!!!

  What can you do with this **DATA CONTAINER** pattern?

  You can create exactly what the name implies: data containers.

  You can create as much containers as you like, one data container for each process or one for the process and one for ist logs or one for all processes data and one for all processes logs.

  **Example**

  This creates a data container with `/data` volume exposed

  <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -v /data --name PGDATA tcode/datastore</pre>

  This binds the actual process (PostgreSQL) to the data container (you need to configure the postgresql.conf accordingly):

    <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -d --volumes-from PGDATA --name pg93 tcode/pg93</pre>

    Now whatever happens to your pg93 container your data will be safe in your PGDATA container.
    If you restart your server when the pg93 container will restart it will find all its data into PGDATA again.

    More interestingly if you need to migrate your data to a new host you can do:

    <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -rm --volumes-from PGDATA -v $(pwd):/backup busybox tar cvf /backup/backup.tar /data</pre>

    This will start a container which will mount the current dir in /backup and load volumes from PGDATA, then it will tar all the data in /data in a comfortable backup.tar file you will find on your current path at container exit!

    Now you can go to another host and recreate your PGDATA data container in the new host:

    <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -v /data --name PGDATA tcode/datastore</pre>

    inject the data back in the data container:

    <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -rm --volumes-from PGDATA -v $(pwd):/backup busybox tar xvf /backup/backup.tar / </pre>

    Start your shiny new postgresql server with all your data:

    <pre><pre class="brush: bash; title: ; notranslate" title="">docker run -d --volumes-from PGDATA --name pg93 tcode/pg93</pre>

## Good Practices

The different kind of data persistence are interesting because they offer hints on how to do things properly in docker.
In this respect docker is not only a commodity over lxcs but is actually shaping up a new way of developing and deploying applications.
Using this wonderful piece of software bring about the need of some new practices.
For example:
- How can I keep my git development process and merge it with docker?
- How can I migrate an existing development/deployment situation to docker?

Answers will widely vary depending on which technologies you are using.

My actual development environment is osx/zsh/git/vim.
I'm developing with Rails.
So my actual development involves process is to change files commit them and then deploy them in production through Capistrano.

How can this change with docker?

Actually I have VirtualBox installed with Vagrant and my development workflow is the following:
1. In Vagrant:
  - Start a database container
  - Start an interactive rails container like this: `docker run -i -t -v /vagrant/rails_app:/data --link databasecontainer:db -p 80:3000 my_rails_image /bin/bash`
  - Run the rails server after proper initialization: `cd /data && bundle install && rails s Puma`
2. In my OSX:
  - `vim /rails_app`
  - hack hack hack
3. In Vagrant container: CTRL+C rails s Puma
4. In my OSX `git push`

And what about deployment?

Deplyoment for a 12 factor app which is already configured to have minimal difference between development and production environments is quite straightforward, the only thing to take care of is getting your code from your git of choice repository:

GitHub

<pre><pre class="brush: bash; title: ; notranslate" title="">curl -sLk -u $REPO_TOKEN:x-oauth-basic https://github.com/$REPO_USER/$REPO_NAME/archive/master.tar.gz -o master.tar.gz</pre>

Bitbucket

<pre><pre class="brush: bash; title: ; notranslate" title="">curl --digest --user $REPO_USER:$REPO_PASSWORD https://bitbucket.org/$REPO_USER/$REPO_NAME/get/master.tar.gz -o master.tar.gz</pre>

More on this in Part 3 which will show the different Dockerfiles.

DATA PERSISTENCE AND DECOUPLICATION:
[http://docs.docker.io/use/working_with_volumes/](http://docs.docker.io/use/working_with_volumes/)
[http://www.offermann.us/2013/12/tiny-docker-pieces-loosely-joined.html](http://www.offermann.us/2013/12/tiny-docker-pieces-loosely-joined.html)
[http://www.tech-d.net/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/](http://www.tech-d.net/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/)
[http://stinemat.es/dockerizing-ghost-part‚Äì2-data-migration/](http://stinemat.es/dockerizing-ghost-part‚Äì2-data-migration/)
[http://www.techbar.me/wordpress-docker/](http://www.techbar.me/wordpress-docker/)
