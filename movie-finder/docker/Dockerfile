FROM nginx

RUN mkdir /app
ADD ./dist/ /app
ADD nginx/nginx.conf /etc/nginx/nginx.conf

WORKDIR /app