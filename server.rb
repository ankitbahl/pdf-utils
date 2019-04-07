require 'sinatra'
require 'sinatra/cors'
require 'combine_pdf'

set :allow_origin, 'https://ankitbahl.github.io/'
set :allow_methods, 'GET,HEAD,POST'
set :allow_headers, 'content-type,if-modified-since'
set :expose_headers, 'location,link'

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
