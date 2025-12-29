# Render 배포 가이드

## 🚀 배포 준비 완료

이 프로젝트는 Render.com 배포를 위한 설정이 완료되었습니다.

## 📋 배포 파일

- [render.yaml](../render.yaml) - Render 서비스 설정
- [bin/render-build.sh](../bin/render-build.sh) - 빌드 스크립트
- [config/puma.rb](../config/puma.rb) - Puma 웹서버 설정 (Render 최적화)

## 🔧 배포 방법

### 1. GitHub 저장소 생성 및 푸시

```bash
git add .
git commit -m "Initial commit: SpaceFit MVP"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/SpaceFit.git
git push -u origin main
```

### 2. Render 계정 생성

https://render.com 에서 GitHub 계정으로 로그인

### 3. 새 서비스 생성

1. Dashboard → "New +" → "Blueprint"
2. GitHub 저장소 연결 (SpaceFit)
3. `render.yaml` 자동 감지됨
4. "Apply" 클릭

### 4. 환경변수 설정

Render Dashboard에서 다음 환경변수 추가:

| 환경변수 | 값 | 설명 |
|---------|-----|------|
| `KAKAO_API_KEY` | `fb649cbf91b24f21ad0d825caecad47a` | 카카오 REST API 키 |
| `RAILS_MASTER_KEY` | (config/master.key 내용) | Rails 암호화 키 |

**RAILS_MASTER_KEY 확인 방법:**
```bash
cat config/master.key
```

### 5. 배포 확인

- Render가 자동으로 빌드 시작
- 빌드 로그에서 진행 상황 확인
- 배포 완료 후 URL 제공: `https://spacefit.onrender.com`

## 🧪 배포 테스트

배포 완료 후 API 테스트:

```bash
curl "https://spacefit.onrender.com/analyze?address=서울%20강남구%20역삼동%20123"
```

예상 응답:
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

## 📊 Render 무료 플랜 제한

- 15분 비활성 시 자동 중지 (첫 요청 시 재시작, ~30초 소요)
- 월 750시간 무료 (1개 서비스 상시 운영 가능)
- PostgreSQL 90일 후 삭제 (데이터 백업 권장)

## 🔄 재배포 방법

코드 수정 후:
```bash
git add .
git commit -m "Update feature"
git push
```

Render가 자동으로 감지하고 재배포합니다.

## 🐛 트러블슈팅

### 빌드 실패 시
- Render 로그에서 에러 확인
- `bin/render-build.sh` 실행 권한 확인
- Gemfile.lock이 저장소에 포함되었는지 확인

### 데이터베이스 연결 오류
- `DATABASE_URL` 자동 설정 확인 (render.yaml)
- PostgreSQL 서비스가 생성되었는지 확인

### API 키 오류
- Render Dashboard → Environment → `KAKAO_API_KEY` 확인
- 환경변수 변경 후 수동 재배포 필요

## 🎯 다음 단계

배포 완료 후:
1. ✅ 실제 서비스 URL 확보
2. ✅ 프론트엔드 연동 가능
3. ✅ 외부 사용자 테스트 가능
4. 커스텀 도메인 연결 (선택사항)
