#! /usr/bin/env ruby
# coding: utf-8

require 'rubygems'
require 'mechanize'
require 'json'
require 'open-uri'
require 'net/http'
require 'pit'


#変数
$ac_ldr #アカウント情報LDR # !> global variable `$ac_ldr' not initialized
$ac_instapaper # アカウント情報 instapeper # !> global variable `$ac_instapaper' not initialized

#アカウントの設定
def account()
  $ac_ldr = Pit::get('ldr', :require => {
                         'user' => 'your id of LDR',
                         'pass' => 'your pass of LDR',
                       })
  
  $ac_instapaper = Pit::get('instapaper', :require => {
                             'user' => 'your id of Instapaper',
                             'pass' => 'your pass of Instapaper',
                           })
end
  

class LDRbrowser
  LDR_TOP_URL='http://reader.livedoor.com/'
  LDR_LOGIN_URL='https://member.livedoor.com/login/index'
  LDR_GET_PIN_URL='http://reader.livedoor.com/api/pin/all'
  LDR_REMOVE_PIN_URL='http://reader.livedoor.com/api/pin/remove'
  
  @@api_key =''
  @@agent = nil

  def initialize
    
    @@agent = WWW::Mechanize.new
    page = @@agent.get(LDR_LOGIN_URL)

    form = page.forms.first
    form.livedoor_id=$ac_ldr['user']
    form.password=$ac_ldr['pass']
    res = @@agent.submit(form) # => #<WWW::Mechanize::Page

    #get API key
    page = @@agent.get(LDR_TOP_URL) # => #<WWW::Mechanize::Page
    @@api_key = @@agent.cookies.find{|c| c.name=='reader_sid'}.value # => "13cc980429ff0a0365acceb8b3570bae"
  end


  #ピンを取得
  def get_pin
    page = @@agent.post(LDR_GET_PIN_URL)
    json = JSON::parse(page.body) 
    return json
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

def add_instapaper(url,title)
  instapaper_api_url='https://www.instapaper.com/api/add' # !> Insecure world writable dir /usr/local/bin in PATH, mode 040777

  #パラメタ
  params=Hash::new
  params['username']=$ac_instapaper['user']
  params['password']=$ac_instapaper['pass'] 
  params['url']=url
  params['title']=title

  agent = WWW::Mechanize.new
  page = agent.post(instapaper_api_url,params)
  return page.code
  
end

# アカウント情報取得
account

#pin情報取得
ldr = LDRbrowser.new
pin_list = ldr.get_pin 

remove_list = Array::new

#instapaperに追加
pin_list.each do |l|
  title = l['title']
  url =  l['link']

  code = add_instapaper(url,title)
  if(code=="201")
    remove_list << url
  end
end

#LDRピンを削除
remove_list.each do |l|
  ldr.remove_pin(l)
end

