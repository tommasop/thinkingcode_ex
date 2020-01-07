{
  "title": "Deployment Rails with Docker Part 1",
  "slug": "deployment-rails-with-docker-part-1",
  "datetime": "2013-12-11T02:33:24.939105Z"
}
---
After my first approach to easying up the many pains of Rails deployment I happened to bump into Docker for a broader PAAS project.
So my thought was: why automate only code deployment if I can automate the whole machine deployment especially with a tool like Docker that makes this task trivial and quick.
---

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
- Use declarative formats for setup automation, to minimize time and cost for new developers joining the project;  
- Have a clean contract with the underlying operating system, offering maximum portability between execution environments;  
- Are suitable for deployment on modern cloud platforms, obviating the need for servers and systems administration;  
- Minimize divergence between development and production, enabling continuous deployment for maximum agility;  
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
    config.logger = ActFluentLoggerRails::Logger.  
    new()  

  - create a config/fluent-logger.yml file
    
    production:
      fluent_host:   '192.168.x.x'
      fluent_port:   24224
      tag:           'foo'
      messages_type: 'string'
      
## Create a vagrant test machine with docker installed

The [Docker guide][15] works flawlessy and deploys a vagrant image through a Dockerfile deploying docker through docker &#8230; awesome!

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
