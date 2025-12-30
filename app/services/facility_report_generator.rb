# frozen_string_literal: true

class FacilityReportGenerator
  # 공공시설 추천에 대한 상세 분석 보고서 생성
  #
  # @param recommendations [Array<Hash>] 추천 시설 목록
  # @param area_indicators [Hash] 상위 지표 점수
  # @param pois [Hash] POI 데이터
  # @param existing_facilities [Hash] 엑셀 기반 기존 시설 데이터
  # @param location [Hash] 분석 위치 정보
  # @return [Hash] 상세 보고서

  def initialize(config_path = Rails.root.join('config', 'public_facilities.yml'))
    @config = YAML.load_file(config_path, symbolize_names: true)
  end

  def generate(recommendations, area_indicators, pois, existing_facilities, location)
    {
      summary: generate_summary(recommendations, area_indicators, location),
      detailed_recommendations: generate_detailed_recommendations(recommendations, area_indicators, pois, existing_facilities),
      area_analysis: generate_area_analysis(area_indicators, pois, existing_facilities, location),
      scoring_breakdown: generate_scoring_breakdown(recommendations, area_indicators),
      comparative_analysis: generate_comparative_analysis(recommendations),
      conclusion: generate_conclusion(recommendations, area_indicators)
    }
  end

  private

  # 1. 요약 정보
  def generate_summary(recommendations, area_indicators, location)
    top_facility = recommendations.first
    strongest_indicator = area_indicators.max_by { |_, score| score }

    {
      location: location[:address],
      coordinates: location,
      analysis_date: Time.current.strftime("%Y-%m-%d %H:%M"),
      top_recommendation: {
        facility_type: top_facility[:facility_type],
        score: top_facility[:score].round(1),
        description: top_facility[:description]
      },
      strongest_characteristic: {
        indicator: indicator_name_to_korean(strongest_indicator[0]),
        score: strongest_indicator[1].round(1)
      },
      total_facilities_analyzed: recommendations.size
    }
  end

  # 2. 추천 시설별 상세 분석
  def generate_detailed_recommendations(recommendations, area_indicators, pois, existing_facilities)
    recommendations.map do |rec|
      facility_rules = @config[:facility_rules][rec[:facility_type].to_sym]
      next unless facility_rules

      {
        rank: rec[:rank],
        facility_type: rec[:facility_type],
        description: rec[:description],
        overall_score: rec[:score].round(1),
        grade: score_to_grade(rec[:score]),

        # 점수 계산 과정
        scoring_detail: {
          base_score: calculate_base_score(facility_rules, area_indicators).round(1),
          indicator_contributions: calculate_indicator_contributions(facility_rules, area_indicators),
          penalties: calculate_penalties_detail(rec[:facility_type], facility_rules, pois, existing_facilities),
          final_score: rec[:score].round(1)
        },

        # 입지 분석
        location_analysis: analyze_location_suitability(rec[:facility_type], facility_rules, area_indicators, pois, existing_facilities),

        # 추천 근거
        recommendation_basis: rec[:reason],

        # 실행 가능성
        feasibility: assess_feasibility(rec[:score], existing_facilities, rec[:facility_type])
      }
    end.compact
  end

  # 3. 지역 특성 종합 분석
  def generate_area_analysis(area_indicators, pois, existing_facilities, location)
    {
      location_type: classify_location_type(area_indicators),

      # 상위 지표 분석
      indicators: area_indicators.map do |name, score|
        {
          name: indicator_name_to_korean(name),
          score: score.round(1),
          grade: score_to_grade(score),
          interpretation: interpret_indicator_score(name, score)
        }
      end,

      # POI 분포
      poi_distribution: analyze_poi_distribution(pois),

      # 기존 시설 현황
      existing_facilities_status: analyze_existing_facilities(existing_facilities, location),

      # 인구 밀도 추정 (POI 기반)
      estimated_population_density: estimate_population_density(pois),

      # 개발 잠재력
      development_potential: assess_development_potential(area_indicators, existing_facilities)
    }
  end

  # 4. 점수 분해 분석
  def generate_scoring_breakdown(recommendations, area_indicators)
    {
      top_3_comparison: recommendations.take(3).map do |rec|
        {
          rank: rec[:rank],
          facility_type: rec[:facility_type],
          score: rec[:score].round(1),
          score_difference_from_top: (recommendations.first[:score] - rec[:score]).round(1)
        }
      end,

      indicator_importance: analyze_indicator_importance(recommendations, area_indicators),

      score_distribution: {
        excellent: recommendations.count { |r| r[:score] >= 80 },
        good: recommendations.count { |r| r[:score] >= 60 && r[:score] < 80 },
        fair: recommendations.count { |r| r[:score] >= 40 && r[:score] < 60 },
        poor: recommendations.count { |r| r[:score] < 40 }
      }
    }
  end

  # 5. 비교 분석
  def generate_comparative_analysis(recommendations)
    {
      top_vs_bottom: compare_top_and_bottom(recommendations),
      category_leaders: identify_category_leaders(recommendations),
      competitiveness: analyze_competitiveness(recommendations)
    }
  end

  # 6. 결론 및 제안
  def generate_conclusion(recommendations, area_indicators)
    top_3 = recommendations.take(3)

    {
      primary_recommendation: {
        facility: top_3.first[:description],
        reason: generate_primary_recommendation_reason(top_3.first, area_indicators)
      },

      alternative_options: top_3[1..2].map do |rec|
        {
          facility: rec[:description],
          reason: "#{rec[:facility_type]}: #{rec[:reason]}"
        }
      end,

      key_considerations: generate_key_considerations(area_indicators, recommendations),

      next_steps: [
        "주민 의견 수렴 및 수요 조사",
        "부지 선정 및 타당성 검토",
        "예산 편성 및 재원 확보 방안 수립",
        "설계 및 인허가 절차 진행"
      ]
    }
  end

  # === Helper Methods ===

  def calculate_base_score(rules, area_indicators)
    raw_score = 0.0
    rules[:indicator_weights].each do |indicator_name, weight|
      indicator_score = area_indicators[indicator_name] || 0.0
      raw_score += indicator_score * weight
    end
    normalize_score(raw_score)
  end

  def calculate_indicator_contributions(rules, area_indicators)
    contributions = []
    rules[:indicator_weights].each do |indicator_name, weight|
      indicator_score = area_indicators[indicator_name] || 0.0
      contribution = indicator_score * weight

      contributions << {
        indicator: indicator_name_to_korean(indicator_name),
        raw_score: indicator_score.round(1),
        weight: weight,
        contribution: contribution.round(1),
        percentage: (contribution / calculate_base_score(rules, area_indicators) * 100).round(1)
      }
    end
    contributions.sort_by { |c| -c[:contribution] }
  end

  def calculate_penalties_detail(facility_type, rules, pois, existing_facilities)
    penalties = []

    # POI 기반 감점
    if rules[:penalty_category]
      poi_key = PublicFacilityRecommender::CATEGORY_CODE_MAPPING[rules[:penalty_category].to_s]
      if poi_key && pois[poi_key]
        existing_count = pois[poi_key].size
        penalty_amount = [[existing_count.to_f / 10.0, 1.0].min * rules[:penalty_weight], rules[:penalty_weight]].min

        penalties << {
          type: "POI 기반 감점",
          reason: "주변 #{category_code_to_korean(rules[:penalty_category])} #{existing_count}개 존재",
          penalty_percentage: (penalty_amount * 100).round(1),
          impact: penalty_amount > 0.1 ? "높음" : "낮음"
        }
      end
    end

    # 엑셀 데이터 기반 감점
    if existing_facilities.any?
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

      excel_category = facility_mapping[facility_type.to_sym]
      if excel_category
        existing_count = existing_facilities.dig(excel_category)&.size || 0
        penalty_amount = [[existing_count.to_f / 3.0, 1.0].min * 0.3, 0.3].min

        if penalty_amount > 0
          penalties << {
            type: "기부채납 시설 감점",
            reason: "기존 #{excel_category} #{existing_count}개 존재",
            penalty_percentage: (penalty_amount * 100).round(1),
            impact: penalty_amount > 0.2 ? "높음" : penalty_amount > 0.1 ? "중간" : "낮음"
          }
        end
      end
    end

    {
      total_penalty_percentage: penalties.sum { |p| p[:penalty_percentage] }.round(1),
      details: penalties
    }
  end

  def analyze_location_suitability(facility_type, rules, area_indicators, pois, existing_facilities)
    strengths = []
    weaknesses = []

    # 강점 분석
    rules[:indicator_weights].each do |indicator_name, weight|
      score = area_indicators[indicator_name] || 0.0
      normalized = normalize_score(score)

      if normalized >= 70
        strengths << "#{indicator_name_to_korean(indicator_name)} 우수 (#{normalized.round(1)}점)"
      end
    end

    # 약점 분석
    rules[:indicator_weights].each do |indicator_name, weight|
      score = area_indicators[indicator_name] || 0.0
      normalized = normalize_score(score)

      if normalized < 50
        weaknesses << "#{indicator_name_to_korean(indicator_name)} 보완 필요 (#{normalized.round(1)}점)"
      end
    end

    # 경쟁 시설
    competition = []
    if rules[:penalty_category]
      poi_key = PublicFacilityRecommender::CATEGORY_CODE_MAPPING[rules[:penalty_category].to_s]
      if poi_key && pois[poi_key]
        competition << "#{category_code_to_korean(rules[:penalty_category])} #{pois[poi_key].size}개"
      end
    end

    {
      strengths: strengths,
      weaknesses: weaknesses,
      competition: competition,
      overall_suitability: strengths.size >= weaknesses.size ? "적합" : "보통"
    }
  end

  def assess_feasibility(score, existing_facilities, facility_type)
    feasibility_score = score

    # 기존 시설이 많으면 실행 가능성 낮음
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

    excel_category = facility_mapping[facility_type.to_sym]
    existing_count = excel_category ? (existing_facilities.dig(excel_category)&.size || 0) : 0

    {
      score: feasibility_score.round(1),
      level: feasibility_score >= 70 ? "높음" : feasibility_score >= 50 ? "중간" : "낮음",
      existing_facilities_impact: existing_count > 3 ? "기존 시설 포화" : existing_count > 0 ? "기존 시설 존재" : "신규 수요 높음",
      recommendation: feasibility_score >= 70 ? "적극 추진 권장" : feasibility_score >= 50 ? "조건부 추진" : "신중한 검토 필요"
    }
  end

  def classify_location_type(area_indicators)
    commercial = area_indicators[:commercial_vitality] || 0
    residential = area_indicators[:residential_demand] || 0
    transportation = area_indicators[:transportation] || 0

    if residential > commercial && residential > 30
      "주거 중심 지역"
    elsif commercial > residential && commercial > 30
      "상업 중심 지역"
    elsif transportation > 40
      "교통 요충지"
    else
      "복합 지역"
    end
  end

  def interpret_indicator_score(indicator_name, score)
    normalized = normalize_score(score)

    interpretation = case normalized
    when 80..100 then "매우 우수한 수준"
    when 60...80 then "양호한 수준"
    when 40...60 then "보통 수준"
    when 20...40 then "개선 필요"
    else "크게 부족"
    end

    case indicator_name
    when :commercial_vitality
      "#{interpretation} - 상권 활성화 #{normalized >= 60 ? '활발' : '부진'}"
    when :residential_demand
      "#{interpretation} - 주거 인프라 #{normalized >= 60 ? '충분' : '부족'}"
    when :transportation
      "#{interpretation} - 교통 접근성 #{normalized >= 60 ? '우수' : '불편'}"
    when :culture_public
      "#{interpretation} - 문화/공공 시설 #{normalized >= 60 ? '풍부' : '빈약'}"
    else
      interpretation
    end
  end

  def analyze_poi_distribution(pois)
    total_pois = pois.values.sum(&:size)

    {
      total_count: total_pois,
      density: total_pois > 100 ? "높음" : total_pois > 50 ? "중간" : "낮음",
      top_categories: pois.sort_by { |_, items| -items.size }.take(5).map do |category, items|
        {
          category: category.to_s,
          count: items.size,
          percentage: (items.size.to_f / total_pois * 100).round(1)
        }
      end
    }
  end

  def analyze_existing_facilities(existing_facilities, location)
    return { status: "데이터 없음" } if existing_facilities.empty?

    total = existing_facilities.values.sum(&:size)

    {
      total_count: total,
      diversity: existing_facilities.keys.size,
      saturation_level: total > 30 ? "포화" : total > 15 ? "보통" : "여유",
      facility_breakdown: existing_facilities.map do |type, items|
        {
          type: type,
          count: items.size,
          percentage: (items.size.to_f / total * 100).round(1)
        }
      end.sort_by { |f| -f[:count] }
    }
  end

  def estimate_population_density(pois)
    # POI 기반 인구 밀도 추정 (휴리스틱)
    residential_pois = (pois[:schools]&.size || 0) + (pois[:daycares]&.size || 0)
    commercial_pois = (pois[:restaurants]&.size || 0) + (pois[:cafes]&.size || 0)

    total = residential_pois + commercial_pois

    {
      level: total > 50 ? "높음" : total > 20 ? "중간" : "낮음",
      estimated_score: total,
      basis: "주거·상업 POI 밀집도 기반 추정"
    }
  end

  def assess_development_potential(area_indicators, existing_facilities)
    avg_indicator = area_indicators.values.sum / area_indicators.size.to_f
    facility_saturation = existing_facilities.values.sum(&:size)

    potential_score = normalize_score(avg_indicator) - (facility_saturation * 2)
    potential_score = [[potential_score, 0].max, 100].min

    {
      score: potential_score.round(1),
      level: potential_score >= 70 ? "높음" : potential_score >= 40 ? "중간" : "낮음",
      reasoning: potential_score >= 70 ? "인프라 우수, 추가 개발 여력 있음" :
                 potential_score >= 40 ? "개발 가능하나 신중한 선택 필요" :
                 "기존 시설 포화, 대체 입지 검토 권장"
    }
  end

  def analyze_indicator_importance(recommendations, area_indicators)
    # 상위 지표별 영향력 분석
    area_indicators.map do |name, score|
      # 해당 지표가 높은 가중치를 받는 시설 개수
      relevant_facilities = recommendations.count do |rec|
        rules = @config[:facility_rules][rec[:facility_type].to_sym]
        rules && rules[:indicator_weights][name].to_f > 0.3
      end

      {
        indicator: indicator_name_to_korean(name),
        score: score.round(1),
        influences_facilities_count: relevant_facilities,
        importance: relevant_facilities > 5 ? "높음" : relevant_facilities > 2 ? "중간" : "낮음"
      }
    end.sort_by { |i| -i[:influences_facilities_count] }
  end

  def compare_top_and_bottom(recommendations)
    return nil if recommendations.size < 2

    top = recommendations.first
    bottom = recommendations.last

    {
      top_facility: {
        type: top[:description],
        score: top[:score].round(1)
      },
      bottom_facility: {
        type: bottom[:description],
        score: bottom[:score].round(1)
      },
      score_gap: (top[:score] - bottom[:score]).round(1),
      interpretation: (top[:score] - bottom[:score]) > 30 ? "명확한 우선순위 존재" : "경쟁적 선택지 다수"
    }
  end

  def identify_category_leaders(recommendations)
    # 카테고리별 최고점 시설
    categories = {
      "주민 편의": [:community_center, :senior_center],
      "교육·보육": [:daycare, :library],
      "여가·건강": [:park, :sports_facility, :playground],
      "기반 시설": [:parking_lot, :health_facility]
    }

    categories.map do |category_name, facility_types|
      leader = recommendations
        .select { |r| facility_types.include?(r[:facility_type].to_sym) }
        .max_by { |r| r[:score] }

      next unless leader

      {
        category: category_name,
        leader: leader[:description],
        score: leader[:score].round(1)
      }
    end.compact
  end

  def analyze_competitiveness(recommendations)
    scores = recommendations.map { |r| r[:score] }
    avg = scores.sum / scores.size.to_f
    std_dev = Math.sqrt(scores.sum { |s| (s - avg)**2 } / scores.size.to_f)

    {
      average_score: avg.round(1),
      standard_deviation: std_dev.round(1),
      competitiveness: std_dev < 10 ? "매우 경쟁적 (점수 근소)" :
                       std_dev < 20 ? "경쟁적" : "명확한 순위",
      score_range: {
        min: scores.min.round(1),
        max: scores.max.round(1)
      }
    }
  end

  def generate_primary_recommendation_reason(top_rec, area_indicators)
    rules = @config[:facility_rules][top_rec[:facility_type].to_sym]
    return top_rec[:reason] unless rules

    # 가장 높은 가중치 2개 지표
    top_indicators = rules[:indicator_weights]
      .sort_by { |_, weight| -weight }
      .take(2)
      .map { |name, _| "#{indicator_name_to_korean(name)} 우수" }

    "#{top_indicators.join(', ')} - 해당 지역에 최적화된 시설입니다."
  end

  def generate_key_considerations(area_indicators, recommendations)
    considerations = []

    # 지표 기반 고려사항
    area_indicators.each do |name, score|
      normalized = normalize_score(score)
      if normalized < 50
        considerations << "#{indicator_name_to_korean(name)} 보완 필요 (현재 #{normalized.round(1)}점)"
      end
    end

    # 점수 분포 기반
    top_3_avg = recommendations.take(3).sum { |r| r[:score] } / 3.0
    if top_3_avg < 60
      considerations << "전반적인 적합도가 중간 수준 - 복합 시설 검토 권장"
    end

    considerations << "주민 참여 의견 수렴 필수" if considerations.empty?

    considerations.take(4)
  end

  def normalize_score(raw_score)
    max_possible = @config.dig(:scoring, :max_possible_score) || 50.0
    normalized = (raw_score / max_possible) * 100
    [[normalized, 0].max, 100].min
  end

  def score_to_grade(score)
    case score
    when 90..100 then 'S'
    when 80...90 then 'A+'
    when 70...80 then 'A'
    when 60...70 then 'B+'
    when 50...60 then 'B'
    when 40...50 then 'C'
    else 'D'
    end
  end

  def indicator_name_to_korean(indicator_name)
    {
      commercial_vitality: '상권 활력도',
      residential_demand: '주거 수요',
      transportation: '교통 접근성',
      culture_public: '문화/공공시설'
    }[indicator_name] || indicator_name.to_s
  end

  def category_code_to_korean(category_code)
    {
      'MT1' => '대형마트', 'CS2' => '편의점', 'PS3' => '어린이집',
      'SC4' => '학교', 'AC5' => '학원', 'PK6' => '주차장',
      'OL7' => '주유소', 'SW8' => '지하철역', 'BK9' => '은행',
      'CT1' => '문화시설', 'AG2' => '중개업소', 'PO3' => '공공기관',
      'AT4' => '관광명소', 'AD5' => '숙박', 'FD6' => '음식점',
      'CE7' => '카페', 'HP8' => '병원', 'PM9' => '약국'
    }[category_code.to_s] || category_code.to_s
  end
end
