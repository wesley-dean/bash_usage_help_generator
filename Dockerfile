FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    make \
    gawk \
    curl \
    coreutils

WORKDIR /work

COPY bash_usage_help_generator.bash /opt/bash_usage_help_generator/
COPY Makefile /opt/bash_usage_help_generator/
COPY generate_usage_help.awk /opt/bash_usage_help_generator/
COPY inject_usage_help.awk /opt/bash_usage_help_generator/

RUN chmod 755 /opt/bash_usage_help_generator/bash_usage_help_generator.bash && \
    mkdir -p /opt/bash_usage_help_generator/lib/vendor && \
    make -f /opt/bash_usage_help_generator/Makefile fetch-minifier

ENTRYPOINT ["/opt/bash_usage_help_generator/bash_usage_help_generator.bash"]
