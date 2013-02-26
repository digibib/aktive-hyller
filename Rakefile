require "pry"
require "./app"

task :console do
  binding.pry
end

task :configure do
  puts "Setting theme color"
  cssfile = File.read("public/css/style.css")
  modified = cssfile.gsub(/(?<=#indicator\sli.active\s{\sbackground:\s)([#\h]*)(?=;)/, "#{SETTINGS['theme_color']}")
  modified.gsub!(/(?<=#left-bar\s{\sbackground:\s)([^;]*)(?=;)/, "#{SETTINGS['leftbar_color']}")
  File.open("public/css/style.css", "w") {|f| f.puts modified}
end
