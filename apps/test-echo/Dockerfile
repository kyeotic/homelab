FROM --platform=linux/amd64 nginx:alpine
RUN printf 'server { listen 80; location / { default_type text/plain; return 200 "hello from test-echo11"; } }' > /etc/nginx/conf.d/default.conf
CMD ["nginx", "-g", "daemon off;"]
