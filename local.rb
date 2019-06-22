require 'sinatra'
require 'sinatra/cors'
require 'combine_pdf'
require 'nokogiri'
require 'net/http'

set :allow_origin, 'http://localhost:8000'
set :allow_methods, 'GET,HEAD,POST, OPTIONS'
set :allow_headers, 'content-type,if-modified-since'
set :expose_headers, 'location,link'
set :port, 4567

def sanitize_input(str)
  chars = str.split('')
  chars.each do |c|
    if (c =~ /[a-zA-Z0-9_ ,]/).nil?
      puts "#{c} is bad char"
      return false
    end
  end
  true
end

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
        url: search_item.css('a')[0].attr('href').split('/').last,
        pic: search_item.css('img')[0].attr('src')
    }
  end.to_json
end

post '/manga' do
  return 'job in progress' if File.exist? 'started.t'
  `rm -rf out`
  `rm -rf public/output.zip`
  `rm done.t`
  url = params['url']
  name = params['name']
  arg1 = params['arg1']
  arg2 = params['arg2']
  puts url
  puts name
  puts arg1
  puts arg2
  `touch started.t`
  args = "#{url} #{arg1} #{arg2} #{name}"
  return 'bad input!' unless sanitize_input(args)
  command = "ruby ../../MangaDownloader/downloader.rb #{args} && zip -r output.zip out && mv output.zip public/output.zip && touch done.t"
  pid = spawn(command)
  Process.detach(pid)
  return 'started'
end

get '/progress' do
  if File.exist? 'done.t'
    return 'done'
  else
    `cat ./progress.t`
  end
end

get '/manga' do
  `rm started.t`
  `rm progress.t`
  send_file 'public/output.zip', :filename => 'output.zip', :type => 'Application/octet-stream'
end