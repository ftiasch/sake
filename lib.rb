# frozen_string_literal: true

require 'http'
require 'nokogiri'

class Twitter
  class Tweet < String
    def initialize(user, tags, tweet)
      @user = user
      @tags = tags
      super tweet
    end

    def reply?
      include? 'Replying to'
    end

    def not_reply?
      !reply?
    end

    def tagged?
      @tags.map { |tag| include? tag }.any?
    end

    def strip_reply
      dup.tap do |s|
        @tags.each { |t| s.gsub!(t, '') }
        s.gsub!(/^Replying to[\\n\s]*@#{@user}/, '')
        s.lstrip!
      end
    end
  end

  def initialize(user, tags)
    @user = user
    @tags = tags
  end

  def fetch
    html = HTTP[user_agent: USER_AGENT].follow.get("https://twitter.com/#{@user}").to_s
    Nokogiri::HTML(html).css('.tweet-container').map { |t| make_tweet t.text.strip }
  rescue StandardError
    []
  end

  def last_tweet(tweets)
    ts = tweets.dup
    ts.filter!(&:tagged?)
    i = ts.index(&:not_reply?)
    return unless i
    return ts[0] if i.zero?

    [ts[i], *ts[0..i - 1].reverse.map(&:strip_reply)].join("\n")
  end

  def make_tweet(tweet)
    Tweet.new @user, @tags, tweet
  end

  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2'
end

class Telegram
  def initialize(post_first, api_token, to)
    @post_first = post_first
    @api_token = api_token
    @to = to
    @last_msg = nil
  end

  def perform_post(msg)
    HTTP.post("https://api.telegram.org/bot#{@api_token}/sendMessage", json: {
                chat_id: @to,
                text: msg
              }).parse['ok']
  rescue StandardError
    false
  end

  def post(msg)
    return unless msg
    return if @last_msg == msg
    return if (@post_first || @last_msg) && !perform_post(msg)

    @last_msg = msg
  end
end

class Healthchecks
  def initialize(url)
    @url = url
  end

  def perform_check
    HTTP.get @url
  rescue StandardError
    false
  end

  def check
    return unless @url

    sleep 60 until perform_check
  end
end
