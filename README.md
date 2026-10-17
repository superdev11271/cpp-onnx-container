# C++ / ONNX Runtime dev container (Ubuntu 22.04, arm64)

A Docker image for building C++ programs that use ONNX Runtime on ARM64 (aarch64), reachable over SSH.

| Component    | Version / details                                          |
|--------------|------------------------------------------------------------|
| OS           | Ubuntu 22.04, `linux/arm64`                                |
| C++ compiler | g++ 11.4 (`build-essential`)                               |
| CMake        | 3.22.1                                                     |
| ONNX Runtime | 1.31.0, CPU, installed in `/usr/local`                     |
| SSH server   | OpenSSH, port 22                                           |
| User         | `master`, password `111`, member of `sudo`                 |

## Build

```bash
docker build -t cpp-onnx-env .
```

- The image is always built for `linux/arm64`. On an x86 PC, Docker Desktop emulates ARM, which is slower.
- The warning `FromPlatformFlagConstDisallowed` is expected. The ARM platform is fixed in the Dockerfile on purpose.
- If an x86 build fails with `qemu: uncaught target signal 11 (Segmentation fault)`, run the build again. This is a random emulator crash and does not happen on real ARM hardware.
- To use another ONNX Runtime version, pass `--build-arg ORT_VERSION=<version>`. The version needs an `onnxruntime-linux-aarch64-<version>.tgz` file on the [ONNX Runtime releases page](https://github.com/microsoft/onnxruntime/releases).

## Run

**Password login.** Without `SSH_PUBLIC_KEY`, you log in with the password `111`:

```bash
docker run -d --name cpp-env -p 2222:22 cpp-onnx-env
```

**Key-only login.** With `SSH_PUBLIC_KEY`, only that key can log in over SSH and the password is refused. The password `111` still works for `sudo`.

```bash
# bash
docker run -d --name cpp-env -p 2222:22 -e SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" cpp-onnx-env
```

```powershell
# PowerShell
docker run -d --name cpp-env -p 2222:22 -e "SSH_PUBLIC_KEY=$(Get-Content ~/.ssh/id_ed25519.pub)" cpp-onnx-env
```

In Windows `cmd`, paste the key text instead: `-e SSH_PUBLIC_KEY="ssh-ed25519 AAAA..."`.

To allow more than one key, put them in `SSH_PUBLIC_KEY` separated by newlines.

## Connect

```bash
ssh -p 2222 master@localhost
```

On another machine, replace `localhost` with that machine's IP address.

## Use ONNX Runtime

Headers are in `/usr/local/include/onnxruntime` and libraries in `/usr/local/lib`.

**With CMake:**

```cmake
cmake_minimum_required(VERSION 3.16)
project(app CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(onnxruntime REQUIRED)
add_executable(app main.cpp)
target_link_libraries(app PRIVATE onnxruntime::onnxruntime)
```

```cpp
#include <onnxruntime_cxx_api.h>
#include <iostream>

int main() {
    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "app");
    std::cout << "ONNX Runtime " << Ort::GetVersionString() << "\n";
}
```

```bash
cmake -S . -B build
cmake --build build
./build/app
```

**Without CMake:**

```bash
g++ -std=c++17 main.cpp -I/usr/local/include/onnxruntime -lonnxruntime -o app
```

## Troubleshooting

**`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`**
The SSH host keys are created when the image is built. Containers from the same image share them, so recreating a container does not trigger this warning. Rebuilding the image from scratch (for example with `--no-cache`) creates new keys. Remove the old entry, then connect again:

```bash
ssh-keygen -R "[localhost]:2222"
```

**`onnxruntime cpuid_info warning: Unknown CPU vendor`**
This appears only when the container runs under x86 emulation. It is harmless and does not appear on real ARM hardware.

## Security

The password `111` is stored in the image, so anyone with the image knows it. If the SSH port can be reached from other machines, run the container with `SSH_PUBLIC_KEY` so that password login over SSH is turned off.
