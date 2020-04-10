FROM nginx:latest
RUN apt-get clean && apt-get update && apt-get install -y nano spawn-fcgi fcgiwrap wget curl libcgi-pm-perl libjson-perl libdigest-sha-perl
RUN sed -i 's/www-data/nginx/g' /etc/init.d/fcgiwrap
RUN chown nginx:nginx /etc/init.d/fcgiwrap
ADD ./vhost.conf /etc/nginx/conf.d/default.conf
RUN mkdir /var/www
COPY custom_403.html /var/www
COPY webcmd.crt /etc/nginx/
COPY webcmd.key /etc/nginx/
COPY logger.pl /var/www/logger.pl
COPY logger.pl /var/www/lister.pl
COPY logger.pl /var/www/digest.pl
WORKDIR /var/www
CMD /etc/init.d/fcgiwrap start && nginx -g 'daemon off;'
