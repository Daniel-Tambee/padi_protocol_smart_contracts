docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "http://gitlab/" \
  --registration-token "Hbo5t7387+plVK2zimGeqoF7rElNd4m5EPbsmH3AhLw=" \
  --executor "docker" \
  --description "local-runner" \
  --docker-image "alpine:latest"