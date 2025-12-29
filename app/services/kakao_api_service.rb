class KakaoApiService
  include HTTParty
  base_uri 'https://dapi.kakao.com'

  CATEGORIES = {
    medical: 'HP8',    # 병원
    school: 'SC4',     # 학교
    factory: 'FD6'     # 공장
  }.freeze

  RADIUS = 1000 # 반경 1km (미터)

  def initialize
    @api_key = ENV['KAKAO_API_KEY']
    raise 'KAKAO_API_KEY is not set' if @api_key.blank?
  end

  # 주소 → 좌표 변환
  def geocode(address)
    response = self.class.get(
      '/v2/local/search/address.json',
      query: { query: address },
      headers: headers
    )

    handle_response(response) do |data|
      return nil if data['documents'].empty?

      doc = data['documents'].first
      {
        address: doc['address_name'],
        lat: doc['y'].to_f,
        lng: doc['x'].to_f
      }
    end
  end

  # POI 검색 (카테고리별)
  def search_poi(lat, lng, category_code)
    response = self.class.get(
      '/v2/local/search/category.json',
      query: {
        category_group_code: category_code,
        x: lng,
        y: lat,
        radius: RADIUS
      },
      headers: headers
    )

    handle_response(response) do |data|
      data['documents'].map { |doc| doc['place_name'] }
    end
  end

  # 모든 카테고리 검색
  def search_all_categories(lat, lng)
    {
      medical: search_poi(lat, lng, CATEGORIES[:medical]),
      schools: search_poi(lat, lng, CATEGORIES[:school]),
      factories: search_poi(lat, lng, CATEGORIES[:factory])
    }
  end

  private

  def headers
    { 'Authorization' => "KakaoAK #{@api_key}" }
  end

  def handle_response(response)
    case response.code
    when 200
      yield response.parsed_response
    when 400
      raise StandardError, 'Invalid request'
    when 401
      raise StandardError, 'Invalid API key'
    when 404
      nil
    else
      raise StandardError, "Kakao API error: #{response.code}"
    end
  rescue HTTParty::Error, Net::OpenTimeout => e
    raise StandardError, "External API unavailable: #{e.message}"
  end
end
