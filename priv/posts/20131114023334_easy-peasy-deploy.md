{
  "title": "Easy Peasy Deploy",
  "slug": "easy-peasy-deploy",
  "datetime": "2013-11-14T02:33:24.939105Z"
}
---
I'm a bit tired of reinventing the wheel every time I need to deploy a rails app.
Capistrano has made the good decision to use rake instead of his own DSL so I'll follow that path.
I need a `deploy.rake` file with some tasks inside.
---
I'm a bit tired of reinventing the wheel every time I need to deploy a rails app.

Capistrano has made the good decision to use rake instead of his own DSL so I'll follow that path.

I need a `deploy.rake` file with some tasks inside.

I want to be able to perform ssh commands but I'd also like a good DSL for this so I ended up using the <a href="https://github.com/capistrano/sshkit" target="_blank">same tool Capistrano uses: sshkit</a>.

It is a very lightweight gem with some good syntactic sugar for ssh commands.  
It basically has four commands that wraps ssh and system commands.  
We can see the use of run_locally and capture in the following task.

<pre class="brush: ruby; title: ; notranslate" title=""># run_locally runs a command on your local machine
  # useful if you need to add LOCAL machine pub key to REMOTE machine authorized_keys if not present
     run_locally do         
        within '~' do        
          remote_authorized_keys = capture("ssh #{MY.deploy_user}@#{MY.machine} 'cat ~/.ssh/authorized_keys'")
          # capture as its name implies captures the stdout of the command and returns a String
          # you can check to see if the the keys include your key
          if !remote_authorized_keys.include?(capture("cat ~/.ssh/id_rsa.pub"))
            execute("cat ~/.ssh/id_rsa.pub | ssh #{MY.deploy_user}@#{MY.machine} 'mkdir ~/.ssh; cat &gt;&gt; ~/.ssh/authorized_keys'")
          end
        end
     end
</pre>

The other two commands `test` and `execute` works together in the following task:

<pre class="brush: ruby; title: ; notranslate" title=""># test returns true or false
  unless test "[ -d /var/rails ]"
      # execute runs the command
      # accepted syntax --&gt; :sudo, :mkdir, :rails || "sudo mkdir rails" or :sudo, "mkdir #{MY.deploy_to}"
      execute :sudo, :mkdir, :rails   
  end
</pre>

Armed with sshkit and my understanding of what a simple rails deployment has to do I ended up with the following ideas about my deploy.rake.

It will be split into several files:

  * Machine Preparation
  * Db setup (with specific file for every supported db starting with PostgreSQL)
  * Deploy with Git

I'm starting with the Deploy part. I'm assuming the following: use of rvm and Ubuntu 12.04. In any case migrating to different tools should not be too painful!

The Deploy script will have three basic tasks:

  1. deploy:setup
  2. deploy:update
  3. deploy:rollback

deploy:setup will

  * clone the repo
  * run bundle install
  * run db:migrate and db:seed
  * run assets:precompile

deploy:update will:

  * fetch the last commit
  * run bundle install if Gemfile is changed
  * run db:migrate if database.yml or db/ folder changed
  * run assets:precompile if assets/ folder changed

deploy:rollback will:

  * check and store if Gemfile, db or assets changed
  * rollback db if changed
  * revert to previous commit (git back, git back, git back to where you once belonged)
  * bundle install if Gemfile was different
  * assets precompile if assets were different

It is not easy to be able to use a remote environment configuration (included a modified $PATH) in ssh (useful if you are in need to use a specifically installed ruby version).

This is because when you are deploying an app ssh won't use an interactive shell but a **non interactive** one. This means that you basically lose all the `.profile .bash_profile .bashrc` configurations.

To be able to add path and env options to your non interactive shell the only solution (please advice if you have another way to do it) seems to edit `/etc/ssh/sshd_config`, and uncomment this line:

<pre class="brush: bash; title: ; notranslate" title="">PermitUserEnvironment yes
</pre>

Configure the environment you want to be loaded in `$HOME/.ssh/environment` and restart sshd.

This works well but leaves a potential security hole in your machine. This is why I'm evaluating if it is possible to wrap the needing calls in two tasks that will change the sshd configuration and revert it back. For now I'll leave it configured this way.

The first problem I need to face is how to share configuration parameters between rake files.

I want to be able to split rake files to have a single file for each concern: `machine.rake deploy.rake database.rake`.

This means that I need to require all those files in my main rake file like this:

<pre class="brush: ruby; title: ; notranslate" title=""># Load all tasks from easy_peasy dir
Dir['./easy_peasy/*.rake'].each{ |f| require f }
</pre>

Requiring files means I can't use local variables to store configuration data because they won't be available.

So I ended up opting for an OpenStruct which enables options definition on the fly, instantiated in a constant available through files:

<pre class="brush: ruby; title: ; notranslate" title=""># Configuration data put in an OpenStruct constant 
  # to make them available to all rake files
  MY = OpenStruct.new
  MY.machine = 'machine_ip_or_dns'
  MY.deploy_user = 'deployer'
  MY.deploy_host = SSHKit::Host.new("#{MY.deploy_user}@#{MY.machine}")
  MY.deploy_to   = 'deploy_folder'
  MY.remote_path = "/var/rails/#{MY.deploy_to}"
  MY.git_repo    = 'git@github.com:user/repo.git'
  MY.git_branch  = 'branch'
</pre>

With this code in place I will be able to call configuration in other files simply by calling:

<pre class="brush: ruby; title: ; notranslate" title="">MY.deploy_user
</pre>

Now here is my bare `deploy.rake` file with the three actions and comments to explain what's going on:

<pre class="brush: ruby; title: ; notranslate" title="">namespace :deploy do
  desc "Easy Peasy Setup"
  task :setup do 
    # Setup directory and permissions on remote host
    on MY.deploy_host do |host|
      unless test "[ -d #{MY.remote_path} ]"
        within "/var/rails" do
          execute :git, :clone, MY.git_repo 
          execute :bundle, :install
          execute :rake, 'db:migrate'
          execute :rake, 'db:seed'
          execute :rake, 'assets:precompile'
        end
      end
    end
  end

  desc "Easy Peasy Update"
  task :update do
    on MY.deploy_host do |host|
      within MY.remote_path do
        execute :git, :fetch
        execute :git, :reset, "--hard origin/#{MY.git_branch}"
        execute :bundle, :install if test("git diff HEAD^ HEAD | grep Gemfile")
        execute :rake, 'db:migrate' if test("git diff HEAD^ HEAD | grep database.yml") || test("git diff HEAD^ HEAD -- db/")
        execute :rake, 'assets:precompile' if test("git diff HEAD^ HEAD -- assets/")
      end
    end
  end
  
  desc "Easy Peasy Rollback"
  task :rollback do 
    on MY.deploy_host do |host|
      within MY.remote_path do
        # Before gitting back I need to rollback the db
        execute :rake, 'db:rollback' if test("git diff HEAD^ HEAD | grep database.yml") || test("git diff HEAD^ HEAD -- db/")
        # And store Gemfile and assets changes before gitting back
        gem_changes = test("git diff HEAD^ HEAD | grep Gemfile")
        assets_changes = test("git diff HEAD^ HEAD -- assets/")
        # I then git back
        execute :git, :reset, '--hard HEAD^' 
        # And eventually perform bundle install and assets precompile
        # if there were previous changes
        execute :bundle, :install if gem_changes
        execute :rake, 'assets:precompile' if assets_changes
      end
    end
  end
end
</pre>

The next article will be about the Machine Preparation.
