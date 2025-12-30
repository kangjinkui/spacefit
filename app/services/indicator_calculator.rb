class IndicatorCalculator
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

  # 상위 지표 계산 (4개)
  def calculate(pois)
    indicators = {}

    @config[:indicators].each do |indicator_name, indicator_config|
      indicators[indicator_name] = calculate_indicator(pois, indicator_config)
    end

    indicators
  end

  private

  # 개별 지표 계산
  def calculate_indicator(pois, indicator_config)
    total_score = 0.0

    indicator_config[:categories].each do |category_code|
      # 카테고리 코드 → 내부 키 변환
      poi_key = CATEGORY_CODE_MAPPING[category_code.to_s]
      next unless poi_key && pois[poi_key]

      weight = indicator_config[:weights][category_code.to_sym] || 1.0

      # POI 목록에서 거리 기반 점수 합산
      poi_list = pois[poi_key]
      category_score = poi_list.sum do |poi|
        distance_weight(poi[:distance]) * weight
      end

      total_score += category_score
    end

    total_score
  end

  # 거리 기반 가중치 (AreaAnalyzer와 동일)
  def distance_weight(distance_meters)
    return 1.0 if distance_meters.to_i.zero?

    # 거리에 따른 감쇠 (1000m = 0.0, 0m = 1.0)
    [1.0 - (distance_meters.to_f / 1000.0), 0.0].max
  end
end
