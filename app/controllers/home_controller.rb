class HomeController < ApplicationController
  layout false
  skip_before_action :verify_authenticity_token

  def index
    @kakao_api_key = ENV['KAKAO_API_KEY'] || 'fb649cbf91b24f21ad0d825caecad47a'
    render html: render_to_string(template: 'home/index', layout: false).html_safe
  end
end
