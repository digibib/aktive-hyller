require 'rake'
require 'rspec/core/rake_task'
require 'cucumber'
require 'cucumber/rake/task'
require 'bundler/setup'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--format doc"
end

Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = 'features --format pretty'
end

task :default => [:spec, :features]

