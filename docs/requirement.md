# 주변 건물 분석 MVP 요구사항 (KISS)

## 🎯 프로젝트 개요
특정 주소 입력 시 반경 1km 내 건물 용도 분석으로 주거/상업 적합성 판단

## 📋 기능 요구사항

### 핵심 기능 (1개)
**GET /analyze?address={address}**

입력: "서울 강남구 역삼동 123" 또는 "삼성동 센트럴아이파크"

**성공 응답 (200)** - 현재 버전
```json
{
  "address": "서울 강남구 역삼동 123",
  "coordinates": {
    "lat": 37.5012,
    "lng": 127.0396
  },
  "analysis": {
    "total_score": 85.3,
    "grade": "A+",
    "living": 45.2,
    "transportation": 30.1,
    "leisure": 10.0,
    "recommend": "주거 최적"
  },
  "details": {
    "counts": {
      "medical": 12,
      "schools": 18,
      "convenience_stores": 25,
      "subway_stations": 3,
      "cafes": 15
    },
    "nearest": {
      "medical": { "name": "서울대병원", "distance": 150 },
      "school": { "name": "역삼초등학교", "distance": 200 }
    },
    "weighted_scores": {
      "living": 45.2,
      "transportation": 30.1,
      "leisure": 10.0
    }
  },
  "poi_list": [
    {
      "name": "서울대병원",
      "category_group_code": "HP8",
      "x": 127.0396,
      "y": 37.5012,
      "distance": 150,
      "address": "서울 강남구 역삼동 123-45"
    }
  ]
}
```

**에러 응답**
```json
// 400 - 잘못된 주소
{"error": "Invalid address format"}

// 404 - 주소 검색 실패
{"error": "Address not found"}

// 503 - 카카오 API 장애
{"error": "External API unavailable"}
```

### 출력필드 (현재 버전)

| 필드 | 내용 | 계산 방식 |
|------|------|----------|
| total_score | 종합 점수 (0-100) | 거리 기반 가중치 합산 후 정규화 |
| grade | 등급 (A+~F) | 점수 구간별 등급 부여 |
| living | 생활편의 점수 | 의료시설 + 학교 + 편의점 (거리 가중치 적용) |
| transportation | 교통접근성 점수 | 지하철역 (거리 가중치 × 3.0) |
| leisure | 여가문화 점수 | 카페 (거리 가중치 × 0.5) |
| recommend | 권장 용도 | A+/A: "주거 최적", B+/B: "주거 적합", 기타: 단계별 |

**카카오 Local API 카테고리 코드** (현재 버전)
```ruby
CATEGORIES = {
  medical: 'HP8',       # 병원
  school: 'SC4',        # 학교
  convenience: 'CS2',   # 편의점
  subway: 'SW8',        # 지하철역
  cafe: 'CE7'           # 카페
}

WEIGHTS = {
  medical: 2.0,
  school: 1.5,
  convenience_store: 0.3,
  subway: 3.0,
  cafe: 0.5
}

RADIUS = 1000  # 반경 1km (미터)
```

## 🛠 기술 스택

| 역할 | 선택 | 이유 |
|------|------|------|
| Backend | Ruby on Rails 7 (API-only) | 당신 익숙, 2시간 완성 |
| Database | ~~PostgreSQL~~ 없음 | ActiveRecord 미사용 (API 전용) |
| Geocoding | 카카오 Geocoding API | 무료, 정확 |
| POI 검색 | 카카오 Local API | 1km 카테고리 완벽 |
| 프론트엔드 | Kakao Maps SDK | 무료, 강력한 지도 기능 |
| 환경변수 관리 | dotenv-rails | API 키 보안 관리 |

**API 키 관리**
- 카카오 REST API 키: `KAKAO_API_KEY` 환경변수
- 카카오 JavaScript API 키: 지도 표시용
- 로컬: `.env` 파일 (`.gitignore` 필수)

---

## 📋 완료된 기능

### ✅ Phase 1: 기본 API 구현 (완료)
- 카카오 Geocoding API (주소 → 좌표)
- 카카오 Local API (POI 검색)
- 점수 계산 로직
- 에러 처리
- JSON API 응답

### ✅ Phase 2: 프론트엔드 및 UI/UX (완료)
**Kakao Maps 연동**
- 지도 인터페이스 구현
- 주소 입력 폼 및 엔터키 지원
- 검색 위치 마커 표시 (빨간색)
- POI 카테고리별 색상 구분 마커
- 검색 반경 1km 원 표시 (보라색, 반투명)

### ✅ Phase 3: 점수 로직 대폭 개선 (완료)
**거리 기반 가중치 시스템**
- 거리에 따른 점수 감쇠 적용 (가까울수록 높은 점수)
- 카테고리별 가중치 설정 (병원 2.0, 지하철 3.0 등)

**점수 체계 개편**
- 0-100점 정규화
- A+~F 등급 시스템 (A+: 80~100점)
- 카테고리별 점수 분리
  - 🏠 생활편의 (의료·교육·편의점)
  - 🚇 교통접근성 (지하철역)
  - ☕ 여가문화 (카페)

**카테고리 확장**
- 기존: 병원(HP8), 학교(SC4), 공장(FD6)
- 현재: 병원(HP8), 학교(SC4), 편의점(CS2), 지하철역(SW8), 카페(CE7)

### ✅ Phase 4: 검색 기능 개선 (완료)
**지명 검색 지원**
- 주소 검색 실패 시 키워드 검색 자동 fallback
- 건물명, 랜드마크 검색 가능
  - ✅ "삼성동 센트럴아이파크"
  - ✅ "강남역"
  - ✅ "코엑스"

### ✅ Phase 5: 인터랙티브 기능 (완료)
**마커 클릭 기능**
- 시설 마커 클릭 시 인포윈도우 표시 (상호명, 주소, 카테고리)
- 오른쪽 패널에 선택된 시설 상세 정보 표시
- X 버튼으로 닫기 가능

**시설 목록 UI**
- 카테고리별 전체 시설 목록 표시
- 거리 가까운 순 자동 정렬
- 시설 항목 클릭 시 지도 자동 이동 및 줌인
- 호버 효과 및 시각적 피드백

### ✅ Phase 6: 기술 최적화 (완료)
- ActiveRecord 의존성 제거 (API 전용 서버)
- POI 상세 정보 반환 (이름, 좌표, 거리, 주소)
- 카테고리별 색상 범례 추가
- DOM 요소 직접 생성으로 이벤트 핸들링 개선

---

## 🚀 다음 단계 (선택사항)

### 1. Render 배포 - 실제 서비스 운영
- `render.yaml` 작성
- 환경변수 설정 (KAKAO_API_KEY)
- 배포 URL 확인

### 2. ~~프론트엔드 추가 - 지도에 시각화~~ ✅ **완료**
- ✅ Kakao Maps API 연동
- ✅ 주소 입력 폼
- ✅ 결과를 지도에 마커 표시
- ✅ POI 카테고리별 색상 구분
- ✅ 검색 반경 원 표시
- ✅ 인터랙티브 마커 및 시설 목록

### 3. ~~점수 로직 개선~~ ✅ **완료**
- ✅ 거리 가중치 적용 (가까울수록 높은 점수)
- ✅ 추가 카테고리 (편의점, 지하철역, 카페)
- ✅ 점수 범위 정규화 (0-100점)
- ✅ 상세 분석 리포트
- ✅ A+~F 등급 시스템

### 4. 캐싱 추가 - 성능 개선 (다음 단계)
- Redis 연동
- 동일 주소 요청 캐싱 (TTL: 24시간)
- API 호출 횟수 절감

### 5. 테스트 작성 - 안정성 확보
- RSpec 설정
- Service 단위 테스트
- Controller 통합 테스트
- API Mock 처리

### 6. 기능 확장
- 여러 주소 일괄 분석 (CSV 업로드)
- 분석 결과 저장 및 이력 조회
- 비교 기능 (A vs B 주소)
- PDF 리포트 생성

---

## 🎊 **축하합니다! 풀스택 MVP가 완성되었습니다!**

### 주요 성과
- ✅ 실시간 주변시설 분석 API
- ✅ 인터랙티브 지도 UI
- ✅ 정교한 점수 시스템
- ✅ 사용자 친화적 UX
- ✅ 확장 가능한 아키텍처
