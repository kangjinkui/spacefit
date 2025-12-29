class HomeController < ApplicationController
  layout false
  skip_before_action :verify_authenticity_token

  def index
    # Use JavaScript API key for Maps SDK (not REST API key)
    @kakao_api_key = ENV['KAKAO_JAVASCRIPT_KEY'] || '6f4a0b013fa4cd9542bb6af9232b9516'
    render html: render_to_string(template: 'home/index', layout: false).html_safe
  end
end
