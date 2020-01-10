require 'spec_helper'

RSpec.describe Racker do
  let(:app) { Rack::Builder.parse_file('config.ru').first }
  let(:start_game) { Codebreaker::Entities::Game.new }
  let(:path) { 'test_data.yml' }

  before do
    File.new(path, 'w+')
    stub_const('Codebreaker::Entities::Storage::FILE_NAME', 'test_data.yml')
    File.write(Codebreaker::Entities::Storage::FILE_NAME, [].to_yaml)
  end

  after { File.delete(path) }

  describe 'statuses' do
    context 'root path' do
      before { get '/' }

      it 'returns ok' do
        expect(last_response).to be_ok
      end

      it { expect(last_response.body).to include I18n.t(:short_rules) }
    end

    context 'unknown routes' do
      before { get '/unknown' }

      it 'returns not found' do
        expect(last_response.body).to include I18n.t(:not_found)
      end
    end

    context 'rules path' do
      before { get '/rules' }

      it 'returns ok' do
        expect(last_response).to be_ok
      end

      it { expect(last_response.body).to include I18n.t(:cb_rules) }
    end

    context 'statistics path' do
      before do
        env 'rack.session', scores: []
        get '/stats'
      end

      it { expect(last_response.body).to include I18n.t(:top_of_players) }
      it { expect(last_response).to be_ok }
    end
  end

  describe '#hint' do
    before do
      start_game.init_game(Codebreaker::Entities::Game::DIFFICULTIES[:hard])
      env 'rack.session', start_game: start_game, hints_wasted: [], level: :easy
      get '/hint'
    end

    it 'add value to session hint array' do
      post '/hint'
      expect(last_request.session[:hints_wasted]).not_to be_empty
      expect(last_request.session[:start_game].code.join).to include(last_request.session[:hints_wasted].join)
    end
  end

  describe '#play' do
    before do
      start_game.init_game(Codebreaker::Entities::Game::DIFFICULTIES[:hard])
      env 'rack.session', start_game: start_game, guess_code: ''
      post '/play', level: 'easy', player_name: 'Denis'
    end

    context 'game page response' do
      it 'response ok status' do
        expect(last_response).to be_ok
      end

      it 'contains player_name' do
        expect(last_response.body).to include I18n.t(:hello_msg, name: last_request.session[:name])
      end
    end

    context 'creates empty Array of used hints' do
      it { expect(last_request.session[:hints_wasted]).to be_a Array }
      it { expect(last_request.session[:hints_wasted]).to be_empty }
    end

    context 'creates empty guess_code before starting the game' do
      it { expect(last_request.session[:guess_code]).to be_a String }
      it { expect(last_request.session[:guess_code]).to be_empty }
    end
  end

  describe '#guess' do
    before do
      start_game.init_game(Codebreaker::Entities::Game::DIFFICULTIES[:hard])
      env 'rack.session', start_game: start_game, hints: [], level: 'easy', player_name: 'Dima'
      post '/guess', guess_code: '1111'
    end

    it 'check response with guess_code' do
      expect(last_request.session[:guess_code]).to be_a String
    end
  end
end
