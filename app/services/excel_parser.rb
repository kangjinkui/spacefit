# frozen_string_literal: true

require 'roo'

class ExcelParser
  # 엑셀 파일의 공공시설 데이터를 파싱하여 구조화된 데이터 반환
  #
  # @param file_path [String] 엑셀 파일 경로
  # @return [Array<Hash>] 파싱된 공공시설 데이터 배열
  #
  # 반환 구조:
  # [
  #   {
  #     name: "어린이공원",
  #     category: "공원",
  #     area: 500.0,
  #     location: "서울시 강남구",
  #     coordinates: { lat: 37.123, lng: 127.456 },
  #     ...기타 필드
  #   }
  # ]
  def self.parse(file_path)
    xlsx = Roo::Spreadsheet.open(file_path)
    sheet = xlsx.sheet(0) # 첫 번째 시트

    # 헤더 행 찾기 (보통 첫 번째 행)
    headers = extract_headers(sheet)

    facilities = []

    # 데이터 행 반복 (헤더 다음 행부터)
    (2..sheet.last_row).each do |row_num|
      row_data = extract_row_data(sheet, row_num, headers)
      facilities << row_data if row_data[:name].present?
    end

    facilities
  rescue => e
    Rails.logger.error "Excel parsing error: #{e.message}"
    []
  end

  # 특정 시설 유형만 필터링
  #
  # @param file_path [String] 엑셀 파일 경로
  # @param facility_types [Array<String>] 필터링할 시설 유형 목록
  # @return [Array<Hash>] 필터링된 시설 데이터
  def self.parse_by_types(file_path, facility_types)
    all_facilities = parse(file_path)
    all_facilities.select { |f| facility_types.include?(f[:category]) }
  end

  private

  # 엑셀 헤더 추출 및 정규화
  def self.extract_headers(sheet)
    headers = {}
    sheet.row(1).each_with_index do |header, idx|
      normalized_key = normalize_header(header)
      headers[idx] = normalized_key if normalized_key
    end
    headers
  end

  # 헤더명을 표준 키로 변환
  def self.normalize_header(header)
    return nil if header.blank?

    header_str = header.to_s.strip

    case header_str
    when /시설명|명칭/i
      :name
    when /시설종류|구분|유형|카테고리/i
      :category
    when /면적|규모/i
      :area
    when /주소|위치|소재지/i
      :location
    when /위도|lat/i
      :latitude
    when /경도|lng|lon/i
      :longitude
    when /설치일|준공일|완료일/i
      :established_date
    when /비고|메모/i
      :notes
    else
      header_str.parameterize.underscore.to_sym
    end
  end

  # 행 데이터 추출
  def self.extract_row_data(sheet, row_num, headers)
    row_data = {}

    headers.each do |col_idx, key|
      value = sheet.cell(row_num, col_idx + 1)
      row_data[key] = normalize_value(key, value)
    end

    # 좌표 통합
    if row_data[:latitude] && row_data[:longitude]
      row_data[:coordinates] = {
        lat: row_data[:latitude].to_f,
        lng: row_data[:longitude].to_f
      }
    end

    row_data
  end

  # 값 정규화 (타입 변환 등)
  def self.normalize_value(key, value)
    return nil if value.blank?

    case key
    when :area, :latitude, :longitude
      value.to_f
    when :established_date
      parse_date(value)
    else
      value.to_s.strip
    end
  end

  # 날짜 파싱 (다양한 형식 지원)
  def self.parse_date(value)
    return nil if value.blank?

    case value
    when Date, DateTime, Time
      value
    when Numeric
      # 엑셀 날짜 숫자 형식 (1900-01-01 기준)
      Date.new(1899, 12, 30) + value.to_i
    else
      Date.parse(value.to_s) rescue nil
    end
  end
end
