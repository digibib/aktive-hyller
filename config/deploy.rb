set :application, "aktive-hyller"
set :repository,  "https://bensinober@github.com/digibib/#{application}.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :user, 'deploy'
set :use_sudo, false
set :branch, 'develop'
set :deploy_via, :remote_cache
set :keep_releases, 5     # How many fallback releases are kept in :deploy_to/releases

server "171.23.133.229", :app, :web, :primary => true
set :deploy_to, "/var/www/#{application}"

# RVM integration
set :rvm_ruby_string, 'ruby-1.9.3-p194'
set :rvm_type, :system

#role :db,  "your primary db-server here", :primary => true # This is where Rails migrations will run
#role :db,  "your slave db-server here"

# if you want to clean up old releases on each deploy uncomment this:
after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

require 'rvm/capistrano'                                # Load RVM's capistrano plugin.
require 'bundler/capistrano' 
