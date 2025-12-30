class KakaoApiService
  include HTTParty
  base_uri 'https://dapi.kakao.com'

  # 카카오 로컬 API 전체 카테고리 (18개)
  CATEGORIES = {
    # 기존 5개
    medical: 'HP8',           # 병원
    school: 'SC4',            # 학교
    convenience: 'CS2',       # 편의점
    subway: 'SW8',            # 지하철역
    cafe: 'CE7',              # 카페

    # 확장 13개
    large_mart: 'MT1',        # 대형마트
    daycare: 'PS3',           # 어린이집, 유치원
    academy: 'AC5',           # 학원
    parking: 'PK6',           # 주차장
    gas_station: 'OL7',       # 주유소, 충전소
    bank: 'BK9',              # 은행
    culture: 'CT1',           # 문화시설
    real_estate: 'AG2',       # 중개업소
    public_office: 'PO3',     # 공공기관
    tourist_spot: 'AT4',      # 관광명소
    accommodation: 'AD5',     # 숙박
    restaurant: 'FD6',        # 음식점
    pharmacy: 'PM9'           # 약국
  }.freeze

  RADIUS = 1000 # 반경 1km (미터)

  def initialize
    @api_key = ENV['KAKAO_API_KEY']
    raise 'KAKAO_API_KEY is not set' if @api_key.blank?
  end

  # 주소 → 좌표 변환 (주소 검색 실패 시 키워드 검색으로 fallback)
  def geocode(address)
    # 1. 먼저 주소 검색 시도
    response = self.class.get(
      '/v2/local/search/address.json',
      query: { query: address },
      headers: headers
    )

    result = handle_response(response) do |data|
      unless data['documents'].empty?
        doc = data['documents'].first
        return {
          address: doc['address_name'],
          lat: doc['y'].to_f,
          lng: doc['x'].to_f
        }
      end
    end

    # 2. 주소 검색 실패 시 키워드 검색 (장소명, POI 이름 등)
    keyword_response = self.class.get(
      '/v2/local/search/keyword.json',
      query: { query: address },
      headers: headers
    )

    handle_response(keyword_response) do |data|
      return nil if data['documents'].empty?

      doc = data['documents'].first
      {
        address: doc['address_name'] || doc['road_address_name'] || doc['place_name'],
        lat: doc['y'].to_f,
        lng: doc['x'].to_f
      }
    end
  end

  # POI 검색 (카테고리별) - 상세 정보 포함
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
      data['documents'].map do |doc|
        {
          place_name: doc['place_name'],
          x: doc['x'],
          y: doc['y'],
          distance: doc['distance'],  # 거리(미터)
          address_name: doc['address_name']
        }
      end
    end
  end

  # 모든 카테고리 검색 (18개)
  def search_all_categories(lat, lng)
    {
      # 기존 5개
      medical: search_poi(lat, lng, CATEGORIES[:medical]),
      schools: search_poi(lat, lng, CATEGORIES[:school]),
      convenience_stores: search_poi(lat, lng, CATEGORIES[:convenience]),
      subway_stations: search_poi(lat, lng, CATEGORIES[:subway]),
      cafes: search_poi(lat, lng, CATEGORIES[:cafe]),

      # 확장 13개
      large_marts: search_poi(lat, lng, CATEGORIES[:large_mart]),
      daycares: search_poi(lat, lng, CATEGORIES[:daycare]),
      academies: search_poi(lat, lng, CATEGORIES[:academy]),
      parkings: search_poi(lat, lng, CATEGORIES[:parking]),
      gas_stations: search_poi(lat, lng, CATEGORIES[:gas_station]),
      banks: search_poi(lat, lng, CATEGORIES[:bank]),
      cultures: search_poi(lat, lng, CATEGORIES[:culture]),
      real_estates: search_poi(lat, lng, CATEGORIES[:real_estate]),
      public_offices: search_poi(lat, lng, CATEGORIES[:public_office]),
      tourist_spots: search_poi(lat, lng, CATEGORIES[:tourist_spot]),
      accommodations: search_poi(lat, lng, CATEGORIES[:accommodation]),
      restaurants: search_poi(lat, lng, CATEGORIES[:restaurant]),
      pharmacies: search_poi(lat, lng, CATEGORIES[:pharmacy])
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
