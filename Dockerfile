# syntax=docker/dockerfile:1
FROM --platform=linux/arm64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG ORT_VERSION=1.31.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        openssh-server \
        sudo \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# ONNX Runtime prebuilt C/C++ library, installed under /usr/local.
# Its bundled CMake/pkg-config files expect headers in include/onnxruntime/ and
# libraries in lib64/, so place headers to match and patch lib64 -> lib.
# ldconfig is retried because it randomly segfaults under QEMU (x86 host building arm64).
RUN curl -fsSL https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-aarch64-${ORT_VERSION}.tgz \
        | tar -xz -C /tmp \
    && cd /tmp/onnxruntime-linux-aarch64-${ORT_VERSION} \
    && mkdir -p /usr/local/include/onnxruntime \
    && cp -r include/. /usr/local/include/onnxruntime/ \
    && cp -a lib/. /usr/local/lib/ \
    && sed -i 's#/lib64#/lib#g' \
        /usr/local/lib/cmake/onnxruntime/onnxruntimeTargets-release.cmake \
        /usr/local/lib/pkgconfig/libonnxruntime.pc \
    && (ldconfig || ldconfig || ldconfig) \
    && rm -rf /tmp/onnxruntime-linux-aarch64-${ORT_VERSION}

RUN useradd -m -s /bin/bash -G sudo master \
    && echo "master:111" | chpasswd

# If SSH_PUBLIC_KEY is set (run time), it becomes master's authorized_keys and
# password login is disabled; otherwise log in with the password.
# SSH host keys are created at image build, so recreated containers keep them.
COPY --chmod=755 <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
SSHD_OPTS=""
if [ -n "$SSH_PUBLIC_KEY" ]; then
    mkdir -p /home/master/.ssh
    printf '%s\n' "$SSH_PUBLIC_KEY" > /home/master/.ssh/authorized_keys
    chown -R master:master /home/master/.ssh
    chmod 700 /home/master/.ssh
    chmod 600 /home/master/.ssh/authorized_keys
    SSHD_OPTS="-o PasswordAuthentication=no"
fi
mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e $SSHD_OPTS
EOF

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
