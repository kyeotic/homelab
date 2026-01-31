FROM nginx:alpine
ENV ECHO_MESSAGE="hello from test-echo"
RUN printf 'server { listen 80; location / { default_type text/plain; return 200 "$ECHO_MESSAGE"; } }' > /etc/nginx/templates/default.conf.template
