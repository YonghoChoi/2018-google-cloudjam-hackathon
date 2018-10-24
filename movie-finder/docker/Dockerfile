FROM nginx

RUN mkdir /app
ADD ./app/dist/ /app
ADD ./app/nginx/nginx.conf /etc/nginx/nginx.conf

WORKDIR /app