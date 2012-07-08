#! /usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'rubygems'
require 'mechanize'
require 'json'
require 'open-uri'
require 'net/http'
require 'clockwork'
require 'logger'

#ロガー作成
$logger = Logger::new( STDOUT )
$logger.level = Logger::INFO

@ril = true ##デフォルトではRILに登録

@time = 10 #デフォルト１０分間隔

#LDR API
class LDRbrowser
  LDR_TOP_URL='http://reader.livedoor.com/'
  LDR_LOGIN_URL='https://member.livedoor.com/login/index'
  LDR_GET_PIN_URL='http://reader.livedoor.com/api/pin/all'
  LDR_REMOVE_PIN_URL='http://reader.livedoor.com/api/pin/remove'
  
  @@api_key =''
  @@agent = nil

  def initialize
    begin
      @@agent = Mechanize.new
      page = @@agent.get(LDR_LOGIN_URL)
      
      form = page.forms.first
      form.livedoor_id= ENV['LDR_USER']
      form.password   = ENV['LDR_PASS']
      res = @@agent.submit(form) 
      
      #get API key
      page = @@agent.get(LDR_TOP_URL) 
      @@api_key = @@agent.cookies.find{|c| c.name=='reader_sid'}.value 
    rescue => err
      $logger.error "API取得でエラーが発生しました。"
      exit
    end
  end


  #ピンを取得
  def get_pin
    begin
      page = @@agent.post(LDR_GET_PIN_URL)
      json = JSON::parse(page.body) 
      return json
    rescue => err
      $logger.error "Pin情報取得でエラーが発生しました。"
      exit
    end
  end
  
  #ピンを削除
  def remove_pin(url)
    params=Hash::new
    params['ApiKey']=@@api_key
    params['link']=url
    page = @@agent.post(LDR_REMOVE_PIN_URL,params)
    return page.code
  end
  
end

#Instapaper API
def add_instapaper(url,title)
  begin
    instapaper_api_url='https://www.instapaper.com/api/add'
    
    #パラメタ
    params=Hash::new
    params['username']=ENV['INSTA_USER']
    params['password']=ENV['INSTA_PASS']
    params['url']=url
    params['title']=title
    
    agent = Mechanize.new
    page = agent.post(instapaper_api_url,params)
    return page.code
  rescue => err
    $logger.error "INSTPAPERへの登録でエラーが発生しました。"
    exit
  end
  
end

#Read it Later API
def add_ril(url,title)
  begin
    ril_api_url='https://readitlaterlist.com/v2/add'

    #パラメタ
    params=Hash::new
    params['apikey']=ENV['RIL_API_KEY']
    params['username']=ENV['RIL_USER']
    params['password']=ENV['RIL_PASS'] 
    params['url']=url
    params['title']=title
    
    agent = Mechanize.new
    page = agent.post(ril_api_url,params)
    #p page.header()
    return page.code
  rescue => err
    $logger.error "RILへの登録でエラーが発生しました。"
    exit
  end

end

#環境変数を確認
def check_env
  error = false
  @ril = false if ENV['INSTA'] == "on"
  if @ril
    if !(ENV['RIL_USER'] || ENV['RIL_PASS'] ||ENV['RIL_API_KEY'])
      $logger.error "環境設定が足りません。[RIL_USER,RIL_PASS,RIL_API_KEY]"
      error = true
    end
  else
    if !(ENV['INSTA_USER'] || ENV['INSTA_PASS'])
      $logger.error "環境設定が足りません。[INSTA_USER,INSTA_PASS]" 
      error = true
    end
  end
  if !(ENV['LDR_USER'] || ENV['LDR_PASS'])
    $logger.error "環境設定が足りません。[LDR_USER,LDR_PASS]" 
    error = true
  end
  
  if ENV['TIME'] =~ /^[+-]?\d+$/
    @time = ENV['TIME'].to_i
  end
  $logger.info "#{@time}分間隔でチェックします"

  #エラーは終了
  exit if error
end

#ピン情報を登録する
def task
  #pin情報取得
  ldr = LDRbrowser.new
  pin_list = ldr.get_pin 
  
  #削除用配列
  remove_list = Array::new
  
  # 指定されたあとで読むサービスに登録
  pin_list.each do |l|
    title = l['title']
    url   = l['link']
    pin_list.each do |l|
      #登録
      if (@ril)
        code = add_ril(url,title)
      else
        code = add_instapaper(url,title)
      end
      if( code=="201" or code=="200")
        #正常登録
        remove_list << url
      end
    end
  end
  
  #重複を取り除く
  remove_list.uniq!
  
  #LDRピンを削除
  remove_list.each do |l|
    ldr.remove_pin(l)
  end
end

check_env

#ジョブの登録
Clockwork::handler do |job|
  $logger.info "LDRピンをあとで読むサービスに登録する"
  task
end

#10分毎繰り返し
Clockwork::every(@time.minutes, 'LDR2READLATER')
