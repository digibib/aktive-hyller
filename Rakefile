require "pry"
require "./app"

task :console do
  binding.pry
end

task :configure do
  cssfile = File.read("public/css/style.css")
  puts "Setting theme color"
  modified = cssfile.gsub(/(?<=#indicator\sli.active\s{\sbackground:\s)([#\h]*)(?=;)/, "#{SETTINGS['theme_color']}")
  leftbar_regex_deactivated = /(\/\*)(background-image.+leftbar.+no-repeat;)(\*\/)/
  leftbar_regex_activated = /(background-image.+leftbar.+no-repeat;)/
  if SETTINGS['leftbar_image']
    puts "Activating leftbar image"
    modified.gsub!(leftbar_regex_deactivated, '\2')
  else
    puts "Deactivating leftbar image"
    modified.gsub!(leftbar_regex_activated, '/*\1*/')
    puts "Setting leftbar color"
    modified.gsub!(/(?<=#left-bar\s{\sbackground:\s)([^;]*)(?=;)/, "#{SETTINGS['leftbar_color']}")
  end
  File.open("public/css/style.css", "w") {|f| f.puts modified}
end
