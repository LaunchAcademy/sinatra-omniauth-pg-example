require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'

get '/' do
  erb :index
end
