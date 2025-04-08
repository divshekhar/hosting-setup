FROM ubuntu:22.04

WORKDIR /deploid

COPY . .

# Make scripts executable
RUN chmod +x *.sh && \
    find . -name "*.sh" -type f -exec chmod +x {} \;

# Start with bash
CMD ["/bin/bash"]