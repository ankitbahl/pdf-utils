require 'sinatra'
require 'sinatra/cors'
require 'webrick/ssl'
require 'webrick/https'
require 'combine_pdf'
require 'nokogiri'
require 'net/http'
require './downloader.rb'

webrick_options = {
    :Port               => 4567,
    :Logger             => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
    :DocumentRoot       => "/ruby/htdocs",
    :SSLEnable          => false,
    # :SSLVerifyClient    => OpenSSL::SSL::VERIFY_NONE,
    # :SSLCertificate     => OpenSSL::X509::Certificate.new(  File.open("cert.pem").read),
    # :SSLPrivateKey      => OpenSSL::PKey::RSA.new(          File.open("privkey.pem").read),
    # :SSLCertName        => [ [ "CN",WEBrick::Utils::getservername ] ],
    :Host => "0.0.0.0"
}

class Server < Sinatra::Base

  configure do
    enable :cross_origin
  end

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

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
    Thread.new {
      run_downloader(url, arg1, arg2, name)
      `zip -r output.zip out && mv output.zip public/output.zip && touch done.t`
    }
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
    `rm -rf out`
    send_file 'public/output.zip', :filename => 'output.zip', :type => 'Application/octet-stream'
  end

  options "*" do
    response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

end

Rack::Handler::WEBrick.run Server, webrick_options
