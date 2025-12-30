# frozen_string_literal: true

class FacilityDataLoader
  # 엑셀 파일에서 기존 공공시설 데이터를 로드하고 AreaAnalyzer에 통합
  #
  # 사용 예시:
  #   loader = FacilityDataLoader.new('docs/기부채납 공공시설 - 수기.xls')
  #   existing_facilities = loader.load_facilities
  #   analyzer = AreaAnalyzer.new(lat, lng, existing_facilities: existing_facilities)

  def initialize(file_path = nil)
    @file_path = file_path || default_excel_path
  end

  # 엑셀 파일에서 시설 데이터 로드
  #
  # @return [Hash] 시설 유형별로 그룹화된 데이터
  #   {
  #     "어린이놀이터" => [{name: "...", location: "...", coordinates: {...}}, ...],
  #     "공원" => [...],
  #     ...
  #   }
  def load_facilities
    return {} unless File.exist?(@file_path)

    facilities = ExcelParser.parse(@file_path)
    group_by_category(facilities)
  rescue => e
    Rails.logger.error "Failed to load facilities: #{e.message}"
    {}
  end

  # 특정 시설 유형만 로드
  #
  # @param facility_types [Array<String>] 로드할 시설 유형
  # @return [Hash] 필터링된 시설 데이터
  def load_by_types(facility_types)
    return {} unless File.exist?(@file_path)

    facilities = ExcelParser.parse_by_types(@file_path, facility_types)
    group_by_category(facilities)
  end

  # 특정 위치 주변의 기존 시설 개수 계산
  #
  # @param lat [Float] 위도
  # @param lng [Float] 경도
  # @param radius [Float] 반경 (미터)
  # @param facility_type [String] 시설 유형 (nil이면 전체)
  # @return [Integer] 주변 시설 개수
  def count_nearby_facilities(lat, lng, radius: 500, facility_type: nil)
    facilities = load_facilities

    if facility_type
      facilities = { facility_type => facilities[facility_type] || [] }
    end

    count = 0
    facilities.each do |_type, items|
      items.each do |item|
        next unless item[:coordinates]

        distance = calculate_distance(
          lat, lng,
          item[:coordinates][:lat], item[:coordinates][:lng]
        )

        count += 1 if distance <= radius
      end
    end

    count
  end

  # 통계 정보 반환
  #
  # @return [Hash] 시설 유형별 개수
  def statistics
    facilities = load_facilities
    stats = {}

    facilities.each do |type, items|
      stats[type] = {
        count: items.count,
        total_area: items.sum { |f| f[:area] || 0 },
        avg_area: items.any? ? (items.sum { |f| f[:area] || 0 } / items.count).round(2) : 0
      }
    end

    stats
  end

  private

  def default_excel_path
    Rails.root.join('docs', '기부채납 공공시설 - 수기.xls').to_s
  end

  def group_by_category(facilities)
    grouped = {}

    facilities.each do |facility|
      category = normalize_category(facility[:category])
      grouped[category] ||= []
      grouped[category] << facility
    end

    grouped
  end

  # 시설 카테고리 정규화 (public_facilities.yml과 매칭)
  def normalize_category(category)
    return "기타" if category.blank?

    category_str = category.to_s.strip

    case category_str
    when /어린이놀이터|놀이터/i
      "어린이놀이터"
    when /공원/i
      "공원"
    when /공용주차장|주차장/i
      "공용주차장"
    when /경로당/i
      "경로당"
    when /어린이집|보육시설/i
      "어린이집"
    when /작은도서관|도서관/i
      "작은도서관"
    when /주민운동시설|운동시설/i
      "주민운동시설"
    when /마을회관|회관/i
      "마을회관"
    when /문화시설/i
      "문화시설"
    when /보건의료시설|의료시설/i
      "보건의료시설"
    else
      category_str
    end
  end

  # Haversine 공식으로 두 좌표 간 거리 계산 (미터)
  def calculate_distance(lat1, lng1, lat2, lng2)
    rad_per_deg = Math::PI / 180
    earth_radius = 6371000 # meters

    dlat = (lat2 - lat1) * rad_per_deg
    dlng = (lng2 - lng1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlng / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius * c
  end
end
