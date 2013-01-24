require 'cgi'

module Soup
  class Client
    attr_accessor :login, :password, :domain, :agent, :session_id, :soup_user_id

    def initialize(login, password)
      @login    = login
      @password = password
      @agent    = Soup::Agent.new
    end

    def get_session_id(page)
      cookie      = page.headers["set-cookie"]
      cookie      = CGI::Cookie.parse(cookie)
      @session_id = cookie["soup_session_id"].first
      @soup_user_id = cookie["soup_user_id"].first
    end

    def redirect_session
      agent.faraday("http://www.soup.io").get do |req|
        req.url "/remote/generate"
        req.params['referer']     = "http://www.soup.io/everyone"
        req.params['host']        = "#{@login}.soup.io"
        req.params['redirect_to'] = "/"
        req.headers["Cookie"]     = "soup_session_id=#{@session_id}"
      end.headers['location']
    end

    def login
      post = { login: @login, password: @password, commit: 'Log in' }
      get_session_id(@agent.post('/login', post))
      get_session_id(@agent.get(redirect_session))
    end

    def get_default_request
      {
        'post[source]' => '',
        'post[body]' => '',
        'post[id]' => '',
        'post[parent_id]' => '',
        'post[original_id]' => '',
        'post[edited_after_repost]' => '',
        'redirect' => '',
        'commit' => 'Save'
      }
    end

    def post_submit(request)
      attempts = 0

      begin
          agent = @agent.faraday("http://#{@login}.soup.io")
          response = agent.post('/save', request) do |req|
              req.headers["Cookie"] = "soup_session_id=#{session_id}"
          end
          check_response(response)
      rescue Exception => e
          attempts += 1
          if attempts < 5 then
              if e.message == "invalid session" then
                  self.login
              end
              sleep 10
              retry
          end
      end
    end

    def check_response(response)
        if response.status == 502 then
            raise "bad gateway"
        end

        cookie = response.headers['set-cookie']
        cookie      = CGI::Cookie.parse(cookie)
        if cookie['soup_session_id'].first == 'invalid' then
            raise "invalid session"
        end
    end

    def new_link(url, title = '', description = '')
      request = get_default_request()
      request['post[type]'] = 'PostLink'
      request['post[source]'] = url
      request['post[title]'] = title
      request['post[body]'] = description
      
      post_submit(request)
    end

    def new_image(url, description = '')
      request = get_default_request()
      request['post[type]'] = 'PostImage'
      request['post[url]'] = url
      request['post[source]'] = url
      request['post[body]'] = description
      
      post_submit(request)
    end

    def new_text(text, title = '')
      request = get_default_request()
      request['post[type]'] = 'PostRegular'
      request['post[title]'] = title
      request['post[body]'] = text
      
      post_submit(request)
    end

    def new_quote(quote, source)
      request = get_default_request()
      request['post[type]'] = 'PostQuote'
      request['post[body]'] = quote
      request['post[title]'] = source
      
      post_submit(request)
    end

    def new_video(youtube_url, description = '')
      request = get_default_request()
      request['post[type]'] = 'PostVideo'
      request['post[embedcode_or_url]'] = youtube_url
      request['post[body]'] = description
      
      post_submit(request)
    end
  end
end
