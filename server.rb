require 'sinatra'
require 'sinatra/cors'
require 'combine_pdf'
require 'nokogiri'
require 'net/http'
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

get '/manga-names/:name' do
  search_term = params['name']
  search_term = search_term.gsub(' ', '_')
  search_url = "https://manganelo.com/search/#{search_term}"
  uri = URI.parse(search_url)
  req = Net::HTTP.new(uri.host, uri.port)
  req.use_ssl = true
  res = req.get(uri.request_uri)
  document = Nokogiri::HTML(res.body)
  document.css('.story_item').map do |search_item|
    {
        title: search_item.css('.story_name a')[0].content,
        url: search_item.css('a')[0].attr('href').split('/').last
    }
  end
end
