#!/bin/bash
# CI 없이 수동 이미지 빌드 · ECR push (초기 · 비상용). 평소에는 GitHub Actions(backend.yml) 가 한다. 담당 이경석
# 사용: ./scripts/build-and-push.sh order-service <tag>
# TODO 이경석: aws ecr get-login-password | docker login → docker build services/$1 → docker tag/push sesac-gojigi-{service}:{sha7}
set -e
echo "TODO: build-and-push $1 $2"
