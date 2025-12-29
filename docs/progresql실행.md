PostgreSQL 실행

docker run -d --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

bundle install
bundle exec rails db:create db:migrate
bundle exec rails server
curl "http://localhost:3000/analyze?address=서울 강남구 역삼동 123"

도커 실행 후 
docker run -d --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16



# 기존 서버 종료
pkill -9 -f puma
rm tmp/pids/server.pid

# 백그라운드로 서버 실행
bundle exec rails server > server.log 2>&1 &

# 서버 로그 확인 (별도 명령어)
tail -f server.log

# API 테스트 (같은 터미널에서 가능)
curl -G "http://localhost:3000/analyze" --data-urlencode "address=서울특별시 강남구 테헤란로 152"
가장 쉬운 방법은 새 터미널 탭을 여는 것입니다!
