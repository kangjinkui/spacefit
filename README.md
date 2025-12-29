# SpaceFit - 주변 건물 분석 API

특정 주소 입력 시 반경 1km 내 건물 용도 분석으로 주거/상업 적합성 판단

## 🚀 빠른 시작

### 1. 환경 설정

```bash
# .env 파일 생성 및 카카오 API 키 설정
cp .env.example .env
# .env 파일에서 KAKAO_API_KEY 값 입력
```

카카오 API 키 발급: https://developers.kakao.com/

### 2. 데이터베이스 설정

PostgreSQL이 실행 중이어야 합니다.

```bash
# Docker로 PostgreSQL 실행 (선택사항)
docker run -d --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

# 데이터베이스 생성
bundle exec rails db:create
bundle exec rails db:migrate
```

### 3. 서버 실행

```bash
bundle install
bundle exec rails server
```

## 📡 API 사용법

### GET /analyze

주소를 기반으로 주변 건물 분석

**요청 예시:**
```
GET http://localhost:3000/analyze?address=서울 강남구 역삼동 123
```

**성공 응답 (200):**
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

**에러 응답:**
- `400` - 잘못된 주소 형식
- `404` - 주소를 찾을 수 없음
- `503` - 외부 API 장애

## 🛠 기술 스택

- **Ruby** 3.2.2
- **Rails** 8.1.1
- **PostgreSQL** 16+
- **카카오 Geocoding API** - 주소 → 좌표 변환
- **카카오 Local API** - POI 검색

## 📊 점수 계산 로직

- **편의성 점수**: 병원 수 + 학교 수
- **위험도**: 공장 수
- **권장 용도**: 공장이 0개면 "주거 최적", 그 외 "주거 부적합"

## 🐳 Docker 배포

```bash
docker build -t space_fit .
docker run -p 3000:3000 -e KAKAO_API_KEY=your_key space_fit
```

## 📝 환경변수

| 변수 | 설명 | 필수 |
|-----|-----|-----|
| `KAKAO_API_KEY` | 카카오 REST API 키 | ✅ |
| `DATABASE_URL` | PostgreSQL 연결 URL | 배포 시 |
