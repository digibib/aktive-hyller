require 'capybara'
require 'capybara/cucumber'
require 'rack_session_access/capybara'

require 'rspec'
#require 'bogus/rspec'

require_relative '../../app.rb'

World do 
  Capybara.app = Sinatra::Application
end
