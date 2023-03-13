FROM jenkins/jenkins:lts-jdk11

# switch to root user and update all packages via apt
USER root
RUN apt-get update

# drop back to the regular jenkins user - good practice
USER jenkins

# Install plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
# RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# The below line will indicate Jenkins that this Jenkins installation is fully configured. 
# Otherwise a banner will appear prompting the user to install additional plugins, which may be inappropriate.
RUN echo 2.0 > /usr/share/jenkins/ref/jenkins.install.UpgradeWizard.state