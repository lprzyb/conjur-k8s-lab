FROM docker.io/library/tomcat:9.0.119-jre17
MAINTAINER huy.do@cyberark.com
RUN rm -rf /usr/local/tomcat/webapps/ROOT
ADD target/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
CMD ["catalina.sh", "run"]