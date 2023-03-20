FROM docker.io/crazymax/ddns-route53:latest

ENV SCHEDULE="*/5 * * * *"

USER ddns-route53
ENTRYPOINT [ "ddns-route53" ]
CMD [ "--config", "/ddns-route53.yml" ]