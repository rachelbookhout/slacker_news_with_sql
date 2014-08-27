require 'sinatra'
require 'pg'

configure :development do
  require 'pry'
  require 'sinatra/reloader'
end

def db_connection
  begin
    connection = PG.connect(dbname: 'slacker_news')

    yield(connection)

  ensure
    connection.close
  end
end

def save_article(poster, url, title, description)
  db_connection do |conn|
    conn.exec("INSERT INTO articles (name, url, description, poster)
                VALUES ($1, $2, $3, $4)", [title, url, description, poster])
  end
end

def find_articles
  answer = db_connection do |conn|
    conn.exec("SELECT * FROM articles
              ORDER BY time_created")
  end
  answer.to_a
end

def find_comments(article_id)
  answer = db_connection do |conn|
    conn.exec("SELECT * FROM comments
              WHERE article_id = $1
              ORDER BY time_created", [article_id])
  end
  answer.to_a
end

def get_article_info(article_id)
  db_connection do |conn|
    conn.exec("SELECT name, url, poster, time_created FROM articles
              WHERE id = $1", [article_id])
  end
end

def already_submitted? post_url
answer = db_connection do |conn|
    conn.exec("SELECT name FROM articles where url = $1", [post_url])
  end
  if answer.to_a.empty?
    return false
  end
  true
end

def post_is_valid?(poster, post_title, post_url, post_description)
  if !field_is_valid? poster
    return false
  elsif !field_is_valid? post_title
    return false

  elsif !url_is_valid? post_url
    return false

  elsif !description_is_valid? post_description
    return false

  elsif already_submitted? post_url
    return false
  end
  true
end

def field_is_valid? post_title
  if post_title == ''
    return false
  end
  true
end

def url_is_valid? post_url
  if post_url !~ (/\.\w+\.\w{2,6}$/)
    return false
  end
  true
end

def description_is_valid? post_description
  if post_description == nil || post_description.length < 20
    return false
  end
  true
end

def format_url url
  if url !~ /^(http:\/\/www\.)/
    if url !~ /^(www\.)/
      url = "www." + url
    end
    url = "http://" + url
  end
  url
end

def submit_comment(poster, title, comment_body, article_id)
  db_connection do |conn|
    conn.exec("INSERT INTO comments (title, comment_body, poster, article_id)
                VALUES ($1, $2, $3, $4)", [title, comment_body, poster, article_id])
  end
end


get '/' do
  @articles = find_articles
  erb :index
end

get '/submit' do
  erb :submit
end

get '/articles/:article_id/comments' do
  @post_id = params[:article_id]
  @article_info = get_article_info @post_id
  @title = "#{@article_info[0]["name"]} comments"
  @comments = find_comments @post_id
  erb :comments
end

post '/submit' do
  @post_title = params[:post_title]
  @post_url = format_url(params[:post_url])
  @post_description = params[:post_description]
  @poster = params[:poster]


  if post_is_valid?(params[:poster], params[:post_title], @post_url, params[:post_description])
    save_article(params[:poster], params[:post_url], params[:post_title], params[:post_description])
  redirect '/'
  else
    @error = 'Invalid input'
    if !field_is_valid? @poster
      @error = 'Name required'
    elsif !field_is_valid? @post_title
      @error = 'Title required'
    elsif !url_is_valid? @post_url
      @error = 'Invalid url'
    elsif !description_is_valid? @post_description
      @error = 'Description must be at least 20 characters'
    elsif already_submitted? @post_url
      @error = 'This URL has already been posted'
    end
    erb :submit
  end
end

post '/articles/:article_id/comments' do
  @post_id = params[:article_id]
  @post_title = params[:post_title]
  @comment_body = params[:comment_body]
  @poster = params[:poster]
  @article_info = get_article_info params[:article_id]
  @comments = find_comments @post_id
  @comment_body = params[:comment_body]

  if field_is_valid?(@poster) && field_is_valid?(params[:comment_body])
    submit_comment(@poster, @post_title, @comment_body, params[:article_id])
    redirect "/articles/#{params[:article_id]}/comments"
  else
    @error = 'Invalid input'
    if !field_is_valid? @poster
      @error = 'Name required'
    elsif !field_is_valid? params[:comment_body]
      @error = 'Post body required'
    end
    erb :comments
  end
end
