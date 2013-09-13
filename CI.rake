require 'rake'
require 'rspec/core/rake_task'
require 'bundler/setup'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--format doc"
end

task :default => [:spec]

