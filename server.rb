require 'sinatra'
require 'sinatra/cors'
require 'combine_pdf'
require './sinatra_ssl'

set :allow_origin, 'https://ankitbahl.github.io'
set :allow_methods, 'GET,HEAD,POST, OPTIONS'
set :allow_headers, 'content-type,if-modified-since'
set :expose_headers, 'location,link'
set :ssl_certificate, 'cert.crt'
set :ssl_key, 'pkey.pem'
set :port, 4567
set :bind, '0.0.0.0'

post '/merge' do
	File.open('files.zip', 'w') do |f|
    	f.write(request.body.read.to_s)
  end
	`mkdir files`
  `mv files.zip files/`
  `yes | unzip files/files.zip -d files/`
  `rm files.zip`
  files = `ls files/ | grep -i .pdf`.split("\n")
  puts files
  pdf = CombinePDF.new
  files.each do |file|
    pdf << CombinePDF.load("files/#{file}")
  end
  pdf.save "combined.pdf"
  `mv combined.pdf public/combined.pdf`
  `rm -rf files`
  File.read(File.join('public', 'combined.pdf'))
end

get '/test' do
	'hello world'
end
