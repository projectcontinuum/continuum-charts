minukubeIp=$(minikube ip)

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=*.${minukubeIp}.nip.io" \
  -addext "subjectAltName=DNS:*.${minukubeIp}.nip.io,DNS:${minukubeIp}.nip.io"

kubectl create secret tls continuum-tls \
  --key /tmp/tls.key \
  --cert /tmp/tls.crt \
  -n continuum-dev