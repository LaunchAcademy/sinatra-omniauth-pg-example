# This will load your environment variables from .env when your apps starts
require 'dotenv'
Dotenv.load

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'omniauth-github'
require 'pg'

require_relative 'models/database'

def production_database_config
  db_url_parts = ENV['DATABASE_URL'].split(/\/|:|@/)

  {
    user: db_url_parts[3],
    password: db_url_parts[4],
    host: db_url_parts[5],
    dbname: db_url_parts[7]
  }
end

configure :production do
  set :database_config, production_database_config
end

configure :development do
  require 'pry'

  set :database_config, { dbname: 'sinatra_omniauth_dev' }
end

configure do
  enable :sessions

  use OmniAuth::Builder do
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET']
  end
end

def user_from_omniauth(auth)
  {
    uid: auth['uid'],
    provider: auth['provider'],
    username: auth['info']['nickname'],
    name: auth['info']['name'],
    email: auth['info']['email'],
    avatar_url: auth['info']['image']
  }
end

def find_or_create_user(attr)
  find_user_by_uid(attr[:uid]) || create_user(attr)
end

def find_user_by_uid(uid)
  sql = 'SELECT * FROM users WHERE uid = $1 LIMIT 1'

  user = Database.connection do |db|
    db.exec_params(sql, [uid])
  end

  user.first
end

def find_user_by_id(id)
  sql = 'SELECT * FROM users WHERE id = $1 LIMIT 1'

  user = Database.connection do |db|
    db.exec_params(sql, [id])
  end

  user.first
end

def create_user(attr)
  sql = %{
    INSERT INTO users (uid, provider, username, name, email, avatar_url)
    VALUES ($1, $2, $3, $4, $5, $6);
  }

  Database.connection do |db|
    db.exec_params(sql, attr.values)
  end
end

def all_users
  Database.connection do |db|
    db.exec('SELECT * FROM users')
  end
end

def authenticate!
  unless current_user
    flash[:notice] = 'You need to sign in before you can go there!'
    redirect '/'
  end
end

helpers do
  def signed_in?
    !current_user.nil?
  end

  def current_user
    find_user_by_id(session['user_id'])
  end
end

get '/' do
  erb :index
end

get '/users' do
  authenticate!
  @users = all_users

  erb :'users/index'
end

get '/auth/github/callback' do
  auth = env['omniauth.auth']
  user_attributes = user_from_omniauth(auth)
  user = find_or_create_user(user_attributes)

  session['user_id'] = user['id']
  flash[:notice] = 'Thanks for logging in!'

  redirect '/users'
end

get '/sign_out' do
  session['user_id'] = nil
  flash[:notice] = 'See ya!'
  redirect '/'
end
