require 'rake'
require 'cucumber'
require 'cucumber/rake/task'
require 'bundler/setup'

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features --format pretty'
end

task :default => [:features]

