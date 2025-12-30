class PublicFacilityRecommender
  # 카테고리 코드 → 내부 키 매핑
  CATEGORY_CODE_MAPPING = {
    'MT1' => :large_marts,
    'CS2' => :convenience_stores,
    'PS3' => :daycares,
    'SC4' => :schools,
    'AC5' => :academies,
    'PK6' => :parkings,
    'OL7' => :gas_stations,
    'SW8' => :subway_stations,
    'BK9' => :banks,
    'CT1' => :cultures,
    'AG2' => :real_estates,
    'PO3' => :public_offices,
    'AT4' => :tourist_spots,
    'AD5' => :accommodations,
    'FD6' => :restaurants,
    'CE7' => :cafes,
    'HP8' => :medical,
    'PM9' => :pharmacies
  }.freeze

  def initialize(config_path = Rails.root.join('config', 'public_facilities.yml'))
    @config = YAML.load_file(config_path, symbolize_names: true)
  end

  # 공공시설 추천
  def recommend(area_indicators, pois, existing_facilities = {})
    recommendations = []

    @config[:facility_rules].each do |facility_type, rules|
      score = calculate_facility_score(facility_type, rules, area_indicators, pois, existing_facilities)

      recommendations << {
        facility_type: facility_type.to_s,
        description: rules[:description],
        score: score,
        reason: generate_reason(facility_type, rules, area_indicators, pois, existing_facilities)
      }
    end

    # 점수 순으로 정렬 후 상위 N개 반환
    top_n = @config.dig(:scoring, :top_n_recommendations) || 5
    sorted = recommendations.sort_by { |r| -r[:score] }

    sorted.take(top_n).each_with_index.map do |rec, index|
      rec.merge(rank: index + 1)
    end
  end

  private

  # 시설별 적합도 점수 계산
  def calculate_facility_score(facility_type, rules, area_indicators, pois, existing_facilities)
    raw_score = 0.0

    # 상위 지표 기반 점수 계산
    rules[:indicator_weights].each do |indicator_name, weight|
      indicator_score = area_indicators[indicator_name] || 0.0
      raw_score += indicator_score * weight
    end

    # 감점 로직 (기존 시설이 많으면)
    if rules[:penalty_category]
      penalty = calculate_penalty(rules[:penalty_category], rules[:penalty_weight], pois)
      raw_score *= (1.0 - penalty)
    end

    # 엑셀 데이터 기반 추가 감점 (실제 기부채납 시설 고려)
    if existing_facilities.any?
      excel_penalty = calculate_excel_penalty(facility_type, existing_facilities)
      raw_score *= (1.0 - excel_penalty)
    end

    # 점수 정규화 (0-100)
    normalize_score(raw_score)
  end

  # 감점 계산 (기존 시설 수 기반)
  def calculate_penalty(penalty_category_code, penalty_weight, pois)
    poi_key = CATEGORY_CODE_MAPPING[penalty_category_code.to_s]
    return 0.0 unless poi_key && pois[poi_key]

    existing_count = pois[poi_key].size

    # 시설 수에 비례하여 감점 (최대 penalty_weight까지)
    # 예: 10개 이상이면 최대 감점
    [[existing_count.to_f / 10.0, 1.0].min * penalty_weight, penalty_weight].min
  end

  # 추천 근거 생성
  def generate_reason(facility_type, rules, area_indicators, pois, existing_facilities)
    reasons = []

    # 상위 2개 지표 추출
    top_indicators = rules[:indicator_weights]
      .sort_by { |_, weight| -weight }
      .take(2)

    top_indicators.each do |indicator_name, weight|
      score = area_indicators[indicator_name] || 0.0
      normalized_score = normalize_score(score)

      indicator_label = indicator_name_to_korean(indicator_name)

      if normalized_score >= 70
        reasons << "#{indicator_label} 우수(#{normalized_score.round(1)}점)"
      elsif normalized_score >= 50
        reasons << "#{indicator_label} 양호(#{normalized_score.round(1)}점)"
      end
    end

    # 감점 요인 (POI 기반)
    if rules[:penalty_category]
      poi_key = CATEGORY_CODE_MAPPING[rules[:penalty_category].to_s]
      if poi_key && pois[poi_key]
        existing_count = pois[poi_key].size
        if existing_count > 5
          category_label = category_code_to_korean(rules[:penalty_category])
          reasons << "기존 #{category_label} #{existing_count}개 존재"
        end
      end
    end

    # 엑셀 데이터 기반 감점 요인
    if existing_facilities.any?
      excel_info = generate_excel_penalty_reason(facility_type, existing_facilities)
      reasons << excel_info if excel_info
    end

    reasons.empty? ? "종합 평가 완료" : reasons.join(", ")
  end

  # 점수 정규화 (0-100)
  def normalize_score(raw_score)
    max_possible = @config.dig(:scoring, :max_possible_score) || 50.0
    normalized = (raw_score / max_possible) * 100
    [[normalized, 0].max, 100].min
  end

  # 지표명 한글 변환
  def indicator_name_to_korean(indicator_name)
    {
      commercial_vitality: '상권 활력도',
      residential_demand: '주거 수요',
      transportation: '교통 접근성',
      culture_public: '문화/공공시설'
    }[indicator_name] || indicator_name.to_s
  end

  # 카테고리 코드 한글 변환
  def category_code_to_korean(category_code)
    {
      'MT1' => '대형마트',
      'CS2' => '편의점',
      'PS3' => '어린이집',
      'SC4' => '학교',
      'AC5' => '학원',
      'PK6' => '주차장',
      'OL7' => '주유소',
      'SW8' => '지하철역',
      'BK9' => '은행',
      'CT1' => '문화시설',
      'AG2' => '중개업소',
      'PO3' => '공공기관',
      'AT4' => '관광명소',
      'AD5' => '숙박',
      'FD6' => '음식점',
      'CE7' => '카페',
      'HP8' => '병원',
      'PM9' => '약국'
    }[category_code.to_s] || category_code.to_s
  end

  # 엑셀 데이터 기반 감점 계산
  # 기부채납 시설 데이터에 해당 시설이 많을수록 감점
  def calculate_excel_penalty(facility_type, existing_facilities)
    # 시설 유형 매핑 (YAML 키 → 엑셀 카테고리)
    facility_mapping = {
      playground: '어린이놀이터',
      park: '공원',
      parking_lot: '공용주차장',
      senior_center: '경로당',
      daycare: '어린이집',
      library: '작은도서관',
      sports_facility: '주민운동시설',
      community_center: '마을회관',
      cultural_facility: '문화시설',
      health_facility: '보건의료시설'
    }

    excel_category = facility_mapping[facility_type]
    return 0.0 unless excel_category

    # 해당 카테고리의 기존 시설 수
    existing_count = existing_facilities.dig(excel_category)&.size || 0

    # 시설 수에 비례하여 감점 (최대 30%)
    # 3개 이상이면 최대 감점
    [[existing_count.to_f / 3.0, 1.0].min * 0.3, 0.3].min
  end

  # 엑셀 데이터 기반 감점 근거 생성
  def generate_excel_penalty_reason(facility_type, existing_facilities)
    facility_mapping = {
      playground: '어린이놀이터',
      park: '공원',
      parking_lot: '공용주차장',
      senior_center: '경로당',
      daycare: '어린이집',
      library: '작은도서관',
      sports_facility: '주민운동시설',
      community_center: '마을회관',
      cultural_facility: '문화시설',
      health_facility: '보건의료시설'
    }

    excel_category = facility_mapping[facility_type]
    return nil unless excel_category

    existing_count = existing_facilities.dig(excel_category)&.size || 0

    if existing_count > 0
      "기부채납 #{excel_category} #{existing_count}개 존재"
    end
  end

end
