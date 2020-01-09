require_relative '../dependencies'
class Racker < Viewer
  attr_reader :request, :start_game

  def self.call(env)
    new(env).response.finish
  end

  def initialize(env)
    @request = Rack::Request.new(env)
    @storage = Codebreaker::Entities::Storage.new
  end

  def response
    case request.path
    when '/' then index
    when '/rules' then rules_view
    when '/play' then play
    when '/hint' then hint
    when '/guess' then guess
    when '/lose' then lose
    when '/win' then win
    when '/stats' then stats
    else error404_view
    end
  end

  def index
    return game_view if exist?(:game)

    menu_view
  end

  def stats
    @request.session[:scores] = @storage.load
    stats_view
  end

  def guess
    Rack::Response.new do |response|
      start_game.attempt_wasted
      return lose unless start_game.attempts.positive?

      guess_code = @request.params['guess_code']
      @request.session[:guess] = guess_code
      @request.session[:guess_code] = start_game.start(guess_code)
      return win if start_game.check_win?(guess_code)

      response.redirect('/play')
    end
  end

  def lose
    return error404_view unless exist?(:game)

    Rack::Response.new(lose_view) do
      destroy_session
    end
  end

  def win
    return error404_view unless exist?(:game)

    Rack::Response.new(win_view) do
      @storage.save_game_results(start_game.to_h(user_name))
      destroy_session
    end
  end

  def used_hints
    return @request.session[:hints_wasted] if exist?(:hints_wasted)

    @request.session[:hints_wasted] = []
  end

  def hint
    Rack::Response.new do |response|
      game = start_game
      return error404_view if game.hints_not_remain?

      used_hints.push(game.hint_take)
      response.redirect('/play')
    end
  end

  def hints_not_remain?
    game = start_game
    game.hints_not_remain?
  end

  def play
    set_guess_code
    @request.session[:game] = start_game
    game_view
  end

  def user_name
    return @request.session[:name] if exist?(:name)

    @request.session[:name] = @request.params['player_name']
  end

  def user_level
    return @request.session[:level] if exist?(:level)

    @request.session[:level] = @request.params['level']
  end

  def user_attempts
    return @request.session[:game].attempts if exist?(:game)

    Codebreaker::Entities::Game::DIFFICULTIES[user_level.to_sym][:attempts]
  end

  def user_hints
    return @request.session[:game].hints.size if exist?(:game)

    Codebreaker::Entities::Game::DIFFICULTIES[user_level.to_sym][:hints]
  end

  def game_code
    @request.session[:game].code
  end

  private

  def destroy_session
    @request.session.clear
  end

  def set_guess_code
    return @request.session[:guess_code] if exist?(:guess_code)

    @request.session[:guess_code] = ''
  end

  def exist?(param)
    @request.session.key?(param)
  end

  def start_game
    @game ||= if exist?(:game)
                @request.session[:game]
              else
                game = Codebreaker::Entities::Game.new
                game.init_game(Codebreaker::Entities::Game::DIFFICULTIES[user_level.to_sym])

                game
              end
  end
end