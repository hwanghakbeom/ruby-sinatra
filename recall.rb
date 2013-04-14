require 'sinatra'
require 'data_mapper'
require 'time'
require 'sinatra/flash'
require 'sinatra/redirect_with_flash'
require 'sqlite3'
require 'cgi'
require 'digest/md5'

SITE_TITLE = "Filter"
SITE_DESCRIPTION = "Twitt your Message"

enable :sessions

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/recall.db")

class User
	include DataMapper::Resource
	property :username, Text, :key =>true
	property :password, Text
	has n, :note
end

class Note
	include DataMapper::Resource
	belongs_to :user
	property :id, Serial
	property :content, Text, :required =>true
	property :created_at, DateTime
end

DataMapper.auto_upgrade!

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end


# 
# Application
#

get '/' do
	@title = 'All Notes'
	erb :login
end

post '/' do
	user = User.get params[:login]
	user_pwd = params[:password]
	user_pwden = Digest::MD5.hexdigest(Digest::MD5.hexdigest(user_pwd) + "salt")
	if user.nil?
		redirect '/regist'
	end
	if user.password.to_s() .to_s().eql?(user_pwden.to_s())
		session[:id] = user.username
		redirect '/login'
	else
		redirect '/regist'
	end
end

get '/login' do
	sess = session[:id]
	getuser = User.get sess
	puts getuser.username
	@notes = Note.all(:user => {:username => getuser.username}, :order => [:created_at.desc])
	puts @notes
 
 	@title = 'All Notes'

 	erb :notes
end	

post '/login' do
	n = Note.new
	sess = session[:id]
	getuser = User.get sess 
	n.user_username = getuser.username
	n.attributes = {
		:content => params[:content],
		:created_at => Time.now
	}
	if n.save
		redirect '/login', :notice => 'good'
	else
		n.errors.each do |e|
			puts e
		end
		redirect '/login', :error => 'failed'
	end
end


get '/regist' do
	@title = 'REGIST'
	erb:regist
end

post '/regist' do
	n = User.new
	user_pwden = Digest::MD5.hexdigest(Digest::MD5.hexdigest(params[:password]) + "salt")
	n.attributes = {
		:username => params[:login],
		:password => user_pwden
	}
	if n.save
		redirect '/' 
	else
		redirect '/regist', :error => 'Failed to regist.'
	end
end

get '/rss.xml' do
	builder :rss
end

get '/filter/user/:username' do
	getuser = User.get params[:username]
	@notes = Note.all(:user => {:username => getuser.username}, :order => [:created_at.desc]) 
	erb :note_all
end

put '/:userid' do
	n = User.get params[:useid]
	unless n
		redirect '/', :error => "Can't find that note."
	end
	n.attributes = {
		:content => params[:content],
		:complete => params[:complete] ? 1 : 0,
		:updated_at => Time.now
	}
	if n.save
		redirect '/', :notice => 'Note updated successfully.'
	else
		redirect '/', :error => 'Error updating note.'
	end
end

get '/:id/delete' do
	@note = User.get params[:userid]
	@title = "Confirm deletion of note ##{params[:id]}"
	if @note
		erb :delete
	else
		redirect '/', :error => "Can't find that note."
	end
end

delete '/:id' do
	n = User.get params[:id]
	if n.destroy
		redirect '/', :notice => 'Note deleted successfully.'
	else
		redirect '/', :error => 'Error deleting note.'
	end
end

get '/:id/complete' do
	n = User.get params[:id]
	unless n
		redirect '/', :error => "Can't find that note."
	end
	n.attributes = {
		:complete => n.complete ? 0 : 1, # flip it
		:updated_at => Time.now
	}
	if n.save
		redirect '/', :notice => 'Note marked as complete.'
	else
		redirect '/', :error => 'Error marking note as complete.'
	end
end
