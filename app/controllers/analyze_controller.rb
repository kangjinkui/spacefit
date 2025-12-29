class AnalyzeController < ApplicationController
  def index
    address = params[:address]

    if address.blank?
      return render json: { error: 'Address parameter is required' }, status: :bad_request
    end

    analyzer = AreaAnalyzer.new
    result = analyzer.analyze(address)

    render json: result, status: :ok
  rescue StandardError => e
    handle_error(e)
  end

  private

  def handle_error(error)
    case error.message
    when 'Address not found'
      render json: { error: 'Address not found' }, status: :not_found
    when /Invalid address/
      render json: { error: 'Invalid address format' }, status: :bad_request
    when /External API unavailable/, /Kakao API error/
      render json: { error: 'External API unavailable' }, status: :service_unavailable
    else
      Rails.logger.error("Unexpected error: #{error.message}\n#{error.backtrace.join("\n")}")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end
end
