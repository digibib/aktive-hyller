#========================
#CONFIG
#========================
set :domain, "aktivehyller.deichman.no"
set :application, "aktive-hyller"
set :scm, :git
set :git_enable_submodules, 1
set :repository, "https://bensinober@github.com/digibib/#{application}.git"
set :branch, "develop"
set :ssh_options, { :forward_agent => true }
set :stage, :production
set :user, "deploy"
set :use_sudo, false
set :runner, "deploy"
set :deploy_to, "/var/www/#{application}"
set :deploy_via, :remote_cache
set :app_server, :passenger
set :keep_releases, 5  # How many fallback releases are kept in :deploy_to/releases
# RVM integration
set :rvm_ruby_string, 'ruby-1.9.3-p194'
set :rvm_type, :system
#========================
#ROLES
#========================
server "171.23.133.229", :app, :web, :db, :primary => true
#========================
#CUSTOM
#========================
namespace :deploy do
  task :start, :roles => :app do
  run "touch #{current_release}/tmp/restart.txt"
end
task :stop, :roles => :app do
  # Do nothing.
end
desc "Restart Application"
  task :restart, :roles => :app do
    run "touch #{current_release}/tmp/restart.txt"
  end
end
