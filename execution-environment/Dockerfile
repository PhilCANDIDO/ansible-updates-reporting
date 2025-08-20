FROM quay.io/ansible/awx-ee:latest

# Copy custom ansible.cfg
COPY ansible-awx-ssh.cfg /etc/ansible/ansible.cfg

# Set environment variables
ENV ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_RETRY_FILES_ENABLED=False \
    ANSIBLE_PIPELINING=True \
    ANSIBLE_GATHERING=smart \
    ANSIBLE_TIMEOUT=30

# Ensure proper permissions
USER 1000