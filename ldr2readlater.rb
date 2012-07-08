#! /usr/bin/env ruby
# coding: utf-8

require 'rubygems'
require 'mechanize'
require 'json'
require 'open-uri'
require 'optparse'
require 'net/http'
require 'pit'

#コマンドラインオプション
def checkoption
  opt = OptionParser.new

  #オプション情報保持用
  opt_hash = Hash::new

  begin 
    #コマンドラインオプション定義
    opt.on('-h','--help','USAGEを表示。')    {|v| puts opt.help;exit }

    opt.on('-i',
           'Instapaperに登録'){
      |v| opt_hash[:i] = v } 

    opt.on('-r',
           'Read it Laterに登録') {
      |v| opt_hash[:r] = v }

    #オプションのパース
    opt.parse!(ARGV)

    if(opt_hash.length==0)
      puts opt.help
      exit
    end

    return opt_hash
  rescue
    #指定外のオプションが存在する場合はUsageを表示
    puts opt.help
    exit
  end
end


#アカウントの設定(LDR)
def account_ldr
  return Pit::get('ldr', :require => {
                         'user' => 'your id of LDR',
                         'pass' => 'your pass of LDR',
                       })
end

#アカウントの設定(Instapaper)
def account_instapaper
  return Pit::get('instapaper', :require => {
                             'user' => 'your id of Instapaper',
                             'pass' => 'your pass of Instapaper',
                           })
end
  
#アカウントの設定(Read it Later)
def account_ril
  return Pit::get('readitlater', :require => {
                             'user' => 'your id of "Read it later"',
                             'pass' => 'your pass of "Read it later"',
                             'api_key' => 'your api_key of "Read it later"',
                           })
end


#LDR API
class LDRbrowser
  LDR_TOP_URL='http://reader.livedoor.com/'
  LDR_LOGIN_URL='https://member.livedoor.com/login/index'
  LDR_GET_PIN_URL='http://reader.livedoor.com/api/pin/all'
  LDR_REMOVE_PIN_URL='http://reader.livedoor.com/api/pin/remove'
  
  @@api_key =''
  @@agent = nil

  def initialize(ac_ldr)
    @@agent = Mechanize.new
    page = @@agent.get(LDR_LOGIN_URL)

    form = page.forms.first
    form.livedoor_id=ac_ldr['user']
    form.password=ac_ldr['pass']
    res = @@agent.submit(form) 
 # !> Insecure world writable dir /usr/local/bin in PATH, mode 040777
    #get API key
    page = @@agent.get(LDR_TOP_URL) 
    @@api_key = @@agent.cookies.find{|c| c.name=='reader_sid'}.value 
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

#Instapaper API
def add_instapaper(url,title,ac_instapaper)
  instapaper_api_url='https://www.instapaper.com/api/add'

  #パラメタ
  params=Hash::new
  params['username']=ac_instapaper['user']
  params['password']=ac_instapaper['pass'] 
  params['url']=url
  params['title']=title

  agent = Mechanize.new
  page = agent.post(instapaper_api_url,params)
  return page.code
  
end

#Read it Later API
def add_ril(url,title,ac_ril)
  ril_api_url='https://readitlaterlist.com/v2/add'

  #パラメタ
  params=Hash::new
  params['apikey']=ac_ril['api_key']
  params['username']=ac_ril['user']
  params['password']=ac_ril['pass'] 
  params['url']=url
  params['title']=title

  agent = Mechanize.new
  page = agent.post(ril_api_url,params)
  #p page.header()
  return page.code
end

#オプションチェック
opt_hash = checkoption

#アカウント情報取得
ac_ldr=account_ldr
if(opt_hash[:i]) then
  ac_instapaper=account_instapaper
end
if(opt_hash[:r]) then
  ac_ril=account_ril
end



#pin情報取得
ldr = LDRbrowser.new(ac_ldr)
pin_list = ldr.get_pin 

#削除用配列
remove_list = Array::new


#instapaperに追加
if(opt_hash[:i]) then
  pin_list.each do |l|
    title = l['title']
    url =  l['link']
    
    code = add_instapaper(url,title,ac_instapaper)
    if(code=="201")
      remove_list << url
    end
  end
end
#instapaperに追加
if(opt_hash[:r]) then
  pin_list.each do |l|
    title = l['title']
    url =  l['link']
    
    code = add_ril(url,title,ac_ril)
    if(code=="200")
      remove_list << url
    end
  end
end

#重複を取り除く
#そもそもInstapaperとread it laterを両方使うとかないような気がするので、
#重複の場合の措置はどうした方がいいだろう。。。
remove_list.uniq!

#LDRピンを削除
remove_list.each do |l|
  ldr.remove_pin(l)
end

