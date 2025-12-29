class HomeController < ApplicationController
  layout false

  def index
    @kakao_api_key = ENV['KAKAO_API_KEY'] || 'fb649cbf91b24f21ad0d825caecad47a'
  end
end
