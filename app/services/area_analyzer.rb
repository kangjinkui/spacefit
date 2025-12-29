class AreaAnalyzer
  def initialize(kakao_api = KakaoApiService.new)
    @kakao_api = kakao_api
  end

  def analyze(address)
    # 1. 주소 → 좌표 변환
    location = @kakao_api.geocode(address)
    raise StandardError, 'Address not found' if location.nil?

    # 2. POI 검색
    pois = @kakao_api.search_all_categories(location[:lat], location[:lng])

    # 3. 점수 계산
    medical_count = pois[:medical].size
    school_count = pois[:schools].size
    factory_count = pois[:factories].size

    convenience_score = medical_count + school_count
    risk_score = factory_count
    recommendation = risk_score.zero? ? '주거 최적' : '주거 부적합'

    # 4. 결과 반환
    {
      address: location[:address],
      coordinates: {
        lat: location[:lat],
        lng: location[:lng]
      },
      analysis: {
        convenience: convenience_score,
        risk: risk_score,
        recommend: recommendation
      },
      details: {
        medical: medical_count,
        schools: school_count,
        factories: factory_count
      }
    }
  end
end
