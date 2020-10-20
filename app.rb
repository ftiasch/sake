#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib'

require 'json'
require 'logger'
require 'yaml'

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2'

def json_parse(data)
  JSON.parse(data) if data
end

if __FILE__ == $PROGRAM_NAME
  logger = if ENV['DOCKER_LOGS']
             Logger.new '/proc/1/fd/1'
           else
             Logger.new $stdout
           end
  logger.level = Logger::INFO

  config = YAML.safe_load File.open('config.yaml').read
  twitter_user = config['twitter_user']
  twitter_tags = config['twitter_tags']
  post_first = ENV['SAKE_POST_FIRST']
  telegram_api_token = ENV['SAKE_TELEGRAM_API_TOKEN']
  telegram_channel = json_parse(ENV['SAKE_TELEGRAM_CHANNEL_JSON']) || config['telegram_channel']
  healthchecks_url = ENV['SAKE_HEALTHCHECKS_URL']
  unless telegram_api_token
    logger.fatal 'No `SAKE_TELEGRAM_API_TOKEN` found in ENV.'
    abort
  end

  twitter = Twitter.new twitter_user, twitter_tags
  telegram = Telegram.new post_first, telegram_api_token, telegram_channel
  healthchecks = Healthchecks.new healthchecks_url
  loop do
    tweets = twitter.fetch
    new_tweet = twitter.last_tweet tweets
    telegram.post new_tweet
    healthchecks.check
    sleep 900 # 15 minutes
  end
end
