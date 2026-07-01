FROM docker.io/library/tomcat:9.0.119-jre17
MAINTAINER huy.do@cyberark.com
ADD target/*.war /usr/local/tomcat/webapps/
EXPOSE 8080
CMD ["catalina.sh", "run"]