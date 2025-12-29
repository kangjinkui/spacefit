주변 건물 분석 MVP 요구사항 (KISS)
🎯 프로젝트 개요
특정 주소 입력 시 반경 1km 내 건물 용도 분석으로 주거/상업 적합성 판단

📋 기능 요구사항
핵심 기능 (1개)
GET /analyze?address={address}
입력: "서울 강남구 역삼동 123"

**성공 응답 (200)**
```json
{
  "address": "서울 강남구 역삼동 123",
  "coordinates": {
    "lat": 37.5012,
    "lng": 127.0396
  },
  "analysis": {
    "convenience": 30,
    "risk": 0,
    "recommend": "주거 최적"
  },
  "details": {
    "medical": 12,
    "schools": 18,
    "factories": 0
  }
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
출력필드
| 필드          | 내용     | 계산               |
| ----------- | ------ | ---------------- |
| convenience | 편의성 점수 | 의료시설 + 학교 수      |
| risk        | 위험도    | 공장 수             |
| recommend   | 권장 용도  | risk=0 → "주거 최적" |

**카카오 Local API 카테고리 코드**
```ruby
CATEGORIES = {
  medical: 'HP8',    # 병원
  school: 'SC4',     # 학교
  factory: 'FD6'     # 공장
}
RADIUS = 1000        # 반경 1km (미터)
```

🛠 기술 스택
| 역할        | 선택                         | 이유            |
| --------- | -------------------------- | ------------- |
| Backend   | Ruby on Rails 7 (API-only) | 당신 익숙, 2시간 완성 |
| Database  | SQLite3 (개발) → PostgreSQL (배포) | Render 무료 제공, 데이터 영속성 |
| Geocoding | 카카오 Geocoding API          | 무료, 정확        |
| POI 검색    | 카카오 Local API              | 1km 카테고리 완벽   |
| 배포        | Render.com                 | Rails 자동 배포   |
| 환경변수 관리  | dotenv-rails               | API 키 보안 관리   |

**API 키 관리**
- 카카오 REST API 키: `KAKAO_API_KEY` 환경변수
- 로컬: `.env` 파일 (`.gitignore` 필수)
- Render: 대시보드에서 환경변수 설정
- `DATABASE_URL` 기반 설정으로 PostgreSQL 자동 전환

📊 예상 결과 (역삼동)
편의성: 30점 (의료12 + 학교18)
위험도: 0점 (공장0)
→ "주거 최적"

## 🚀 구현 로드맵

### 1단계: 프로젝트 생성 (5분)
```bash
rails new SpaceFit --api --database=postgresql
cd SpaceFit
bundle add httparty dotenv-rails
```

### 2단계: 카카오 API 연동 테스트 (30분)
- Geocoding API: 주소 → 좌표 변환
- Local API: 좌표 기준 POI 검색 (HP8, SC4, FD6)
- `.env` 파일에 `KAKAO_API_KEY` 설정

### 3단계: 점수 계산 로직 (20분)
```ruby
# app/services/area_analyzer.rb
class AreaAnalyzer
  def analyze(lat, lng)
    medical = search_poi(lat, lng, 'HP8').size
    schools = search_poi(lat, lng, 'SC4').size
    factories = search_poi(lat, lng, 'FD6').size

    {
      convenience: medical + schools,
      risk: factories,
      recommend: factories.zero? ? "주거 최적" : "주거 부적합"
    }
  end
end
```

### 4단계: 컨트롤러 통합 (20분)
```ruby
# app/controllers/analyze_controller.rb
class AnalyzeController < ApplicationController
  def index
    # Geocoding → POI 검색 → 점수 계산
  end
end
```

### 5단계: 에러 처리 (15분)
- 주소 검증
- API 실패 처리 (rescue HTTParty::Error)
- JSON 에러 응답 포맷

### 6단계: Render 배포 (10분)
- `render.yaml` 작성
- 환경변수 `KAKAO_API_KEY` 설정
- PostgreSQL 자동 프로비저닝

**예상 총 시간**: 1시간 40분

---

## 📋 완료된 기능
✅ 카카오 Geocoding API (주소 → 좌표)
✅ 카카오 Local API (POI 검색)
✅ 점수 계산 로직
✅ 에러 처리
✅ JSON API 응답
✅ PostgreSQL 연결 (WSL 환경)

---

## 🚀 다음 단계 (선택사항)

### 1. Render 배포 - 실제 서비스 운영
- `render.yaml` 작성
- 환경변수 설정 (KAKAO_API_KEY, DATABASE_URL)
- PostgreSQL 자동 프로비저닝
- 배포 URL 확인

### 2. 프론트엔드 추가 - 지도에 시각화
- Kakao Maps API 연동
- 주소 입력 폼
- 결과를 지도에 마커 표시
- POI 카테고리별 색상 구분

### 3. 점수 로직 개선
- 거리 가중치 적용 (가까울수록 높은 점수)
- 추가 카테고리 (편의점, 지하철역, 공원 등)
- 점수 범위 정규화 (0-100점)
- 상세 분석 리포트

### 4. 캐싱 추가 - 성능 개선
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

🎊 **축하합니다! MVP가 완성되었습니다!**
