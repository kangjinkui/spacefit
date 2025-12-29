class AreaAnalyzer
  # 카테고리별 가중치 설정
  WEIGHTS = {
    medical: 2.0,
    school: 1.5,
    convenience_store: 0.3,
    subway: 3.0,
    cafe: 0.5
  }.freeze

  def initialize(kakao_api = KakaoApiService.new)
    @kakao_api = kakao_api
  end

  def analyze(address)
    # 1. 주소 → 좌표 변환
    location = @kakao_api.geocode(address)
    raise StandardError, 'Address not found' if location.nil?

    # 2. POI 검색
    pois = @kakao_api.search_all_categories(location[:lat], location[:lng])

    # 3. 거리 기반 점수 계산
    scores = calculate_weighted_scores(pois)

    # 4. 최종 점수 및 등급 계산 (0-100점)
    total_score = normalize_score(scores[:total])
    grade = calculate_grade(total_score)

    # 5. POI 리스트 생성 (지도 마커용)
    poi_list = build_poi_list(pois)

    # 6. 상세 분석 리포트
    detailed_analysis = build_detailed_analysis(pois, scores)

    # 7. 결과 반환
    {
      address: location[:address],
      coordinates: {
        lat: location[:lat],
        lng: location[:lng]
      },
      analysis: {
        total_score: total_score.round(1),
        grade: grade,
        living: scores[:living].round(1),
        transportation: scores[:transportation].round(1),
        leisure: scores[:leisure].round(1),
        recommend: recommend_usage(grade)
      },
      details: detailed_analysis,
      poi_list: poi_list
    }
  end

  private

  # 거리 기반 가중치 계산 (가까울수록 높은 점수)
  def distance_weight(distance_meters)
    return 1.0 if distance_meters.to_i.zero?

    # 거리에 따른 감쇠 (1000m = 0.0, 0m = 1.0)
    [1.0 - (distance_meters.to_f / 1000.0), 0.0].max
  end

  # 카테고리별 점수 계산
  def calculate_weighted_scores(pois)
    # 의료시설 점수
    medical_score = pois[:medical].sum do |poi|
      WEIGHTS[:medical] * distance_weight(poi[:distance])
    end

    # 학교 점수
    school_score = pois[:schools].sum do |poi|
      WEIGHTS[:school] * distance_weight(poi[:distance])
    end

    # 편의점 점수
    convenience_score = pois[:convenience_stores].sum do |poi|
      WEIGHTS[:convenience_store] * distance_weight(poi[:distance])
    end

    # 지하철역 점수
    subway_score = pois[:subway_stations].sum do |poi|
      WEIGHTS[:subway] * distance_weight(poi[:distance])
    end

    # 카페 점수
    cafe_score = pois[:cafes].sum do |poi|
      WEIGHTS[:cafe] * distance_weight(poi[:distance])
    end

    # 카테고리별 그룹핑
    living = medical_score + school_score + convenience_score
    transportation = subway_score
    leisure = cafe_score

    {
      living: living,
      transportation: transportation,
      leisure: leisure,
      total: living + transportation + leisure
    }
  end

  # 점수 정규화 (0-100점)
  def normalize_score(raw_score)
    # 예상 최대 점수를 기준으로 정규화 (최대 20개 POI 가정)
    max_possible = 30.0
    normalized = (raw_score / max_possible) * 100
    [[normalized, 0].max, 100].min  # 0-100 범위로 제한
  end

  # 등급 계산
  def calculate_grade(score)
    case score
    when 80..100 then 'A+'
    when 70...80 then 'A'
    when 60...70 then 'B+'
    when 50...60 then 'B'
    when 40...50 then 'C'
    when 30...40 then 'D'
    else 'F'
    end
  end

  # 추천 용도 결정
  def recommend_usage(grade)
    return '주거 최적' if ['A+', 'A'].include?(grade)
    return '주거 적합' if ['B+', 'B'].include?(grade)
    return '주거 보통' if grade == 'C'
    '인프라 부족'
  end

  # POI 리스트 생성
  def build_poi_list(pois)
    list = []

    pois.each do |category, items|
      category_code = category_to_code(category)
      list += items.map { |poi| format_poi(poi, category_code) }
    end

    list
  end

  # 카테고리명 → 코드 변환
  def category_to_code(category)
    {
      medical: 'HP8',
      schools: 'SC4',
      convenience_stores: 'CS2',
      subway_stations: 'SW8',
      cafes: 'CE7'
    }[category] || 'ETC'
  end

  # POI 포맷팅
  def format_poi(poi, category_code)
    {
      name: poi[:place_name],
      category_group_code: category_code,
      x: poi[:x].to_f,
      y: poi[:y].to_f,
      distance: poi[:distance].to_i,
      address: poi[:address_name]
    }
  end

  # 상세 분석 리포트
  def build_detailed_analysis(pois, scores)
    {
      counts: {
        medical: pois[:medical].size,
        schools: pois[:schools].size,
        convenience_stores: pois[:convenience_stores].size,
        subway_stations: pois[:subway_stations].size,
        cafes: pois[:cafes].size
      },
      nearest: {
        medical: nearest_poi(pois[:medical]),
        school: nearest_poi(pois[:schools]),
        convenience_store: nearest_poi(pois[:convenience_stores]),
        subway: nearest_poi(pois[:subway_stations]),
        cafe: nearest_poi(pois[:cafes])
      },
      weighted_scores: {
        living: scores[:living].round(1),
        transportation: scores[:transportation].round(1),
        leisure: scores[:leisure].round(1)
      }
    }
  end

  # 가장 가까운 POI 찾기
  def nearest_poi(poi_list)
    return nil if poi_list.empty?

    nearest = poi_list.min_by { |poi| poi[:distance].to_i }
    {
      name: nearest[:place_name],
      distance: nearest[:distance].to_i
    }
  end
end
