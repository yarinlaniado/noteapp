# Use the official Filebeat image
FROM docker.elastic.co/beats/filebeat:7.15.0
# Copy the Filebeat configuration
COPY filebeat.yml /usr/share/filebeat/filebeat.yml

# Switch to the root user to change file permissions and ownership
USER root

# Adjust file permissions and ownership
RUN chmod 644 /usr/share/filebeat/filebeat.yml && chown root:filebeat /usr/share/filebeat/filebeat.yml

# Set the Filebeat configuration file as the entry point
CMD ["-c", "/usr/share/filebeat/filebeat.yml"]
