{
  "title": "Multithreaded rails app 4 real",
  "slug": "multithreaded-rails-app-4-real",
  "datetime": "2013-10-29T02:33:24.939105Z"
}
---
Rubinius 2.0 (actually 2.1.1) is out and with it rails apps can finally be fully multithreaded taking advantage of multicore processors and substantially reducing memory consumption.
Im currently porting a Rails 2 app to Rails 4. It is a patients management app with also image management.
Some doctors have up to 4000 patients.
---

[Rubinius 2.0][1] (actually 2.1.1) is out and with it rails apps can finally be fully multithreaded taking advantage of multicore processors and substantially reducing memory consumption ([benchmark of latest ruby implementations][2]).

Im currently porting a Rails 2 app to Rails 4. It is a patients management app with also image management.

Some doctors have up to 4000 patients.

My aim is to publish an alpha version of the revamped app on my local home server to let the users actually try the changes and be able to change the final output. At the same time the alpha deployment stack will be the same as the production deployment stack that is to say:

  * Rubinius 2.x
  * rvm
  * Nginx
  * Puma
  * Capistrano

Actually my home server hosts my wordpress website served by apache2 on a debian distribution.

So here goes my project's shopping list:

  * Install Rubinius 2.1.1
  * Install nginx and make it serve the rails puma app while still serving the apache2 installed sites
  * Install puma and let it start as a daemon
  * Configure Capistrano to deploy the alpha Rails 4 app to the selected stack

First thing first just get rvm and install it:

As stated on <a href="http://rubini.us/2013/09/22/ready-set/" target="_blank">rubinius blog</a> to build rubinius 2 you either need rubinius master or ruby MRI 2. But luckily rvm automatically installs the MRI 2 for you so all you need is <a href="http://rvm.io" target="_blank">love! for rvm which needs some money for its version 2</a>!

This will install MRI 2 and rubinius 2.1.1 (at writing time).

So now that we have rubinius installed let's proceed with our world domination program and see how we can install nginx and configure it as a reverse proxy to serve this wordpress site running on apache 2 (if you can read this it's working …. phew)!

Just one thing to note, you need to set the `client_max_body_size` to use the automatic wordpress updates and installation of themes and plugins from zip files located on your device. Next we need to configure Apache 2 to listen on a different port than 80, I'm using 8080. Change `/etc/apache2/ports.conf`, `/etc/apache2/apache2.conf` and every virtual host directive to listen and answer to port 8080:

Restarting Apache and reloading nginx will bring online the new web server asset serving rails apps through nginx and php apps through apache2.

Next we need to install puma and configure nginx to serve puma applications. As I'm deploying a rails 4 app installing puma means adding a gem to my `Gemfile`

and then doing a `bundle install`.

Next we configure nginx to serve a puma app listening on a unix socket. We add a site to `/etc/nginx/sites-available/` and paste this configuration inside it:



The paths in the configuration are based on my Capistrano `deploy.rb` which we'll see in a minute. It's a git based capistrano recipe using a `web` prefix folder.

Next we need to configure puma and capistrano in our app modifying `config/puma.rb` and `config/deploy.rb`.

See the <a href="https://github.com/puma/puma/blob/master/examples/config.rb" target="_blank">puma.rb example file</a> to get you started, here is my puma configuration:

The puma init.d script which will take care of starting and stopping puma daemons for every rails app is:

And now the core of every Rails deployment: the `deploy.rb` file in all its glory.

**DO YOU REALLY WANT A 500 LINES DEPLOY SCRIPT BACKED BY A FULL GEM?**

I'm tired of handling resources, shared, current and all the rvm, bundler tricks without knowing exactly what I'm doing so please see my [next post for an easy peasy deploy solution in Rails][3].

 [1]: http://rubini.us/2013/10/04/rubinius-2-0-released/
 [2]: http://miguelcamba.com/blog/2013/10/05/benchmarking-the-ruby-2-dot-1-and-rubinius-2-dot-0/
 [3]: http://thinkingco.de/2013/uncategorized/easy-peasy-deploy
