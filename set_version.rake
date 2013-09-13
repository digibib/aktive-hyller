task :default do
	version = ENV['AHVERSION']
	text = "div id='ahversion'\n\tVersion #{version}"
	File.open('views/version.slim', 'w') {|file| file.write(text)}
end