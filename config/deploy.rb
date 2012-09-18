#========================
#CONFIG
#========================
default_run_options[:pty] = true
set :domain, "aktivehyller.deichman.no"
set :application, "aktive-hyller"
set :scm, :git
set :git_enable_submodules, 1
set :repository, "https://bensinober@github.com/digibib/#{application}.git"
set :branch, "develop"
set :git_shallow_clone, 1
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
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
 
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
 
    # mkdir -p is making sure that the directories are there for some SCM's that don't save empty folders
    run <<-CMD
      rm -rf #{latest_release}/log &&
      mkdir -p #{latest_release}/public &&
      mkdir -p #{latest_release}/tmp &&
      ln -s #{shared_path}/log #{latest_release}/log
    CMD
 
    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = %w(images css).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end
end                           # Bundler integration
