# C++ / ONNX Runtime dev container (Ubuntu 22.04, amd64)

A Docker image for building C++ programs that use ONNX Runtime on x86-64 (amd64), reachable over SSH.

| Component    | Version / details                                          |
|--------------|------------------------------------------------------------|
| OS           | Ubuntu 22.04, `linux/amd64`                                |
| C++ compiler | g++ 11.4 (`build-essential`)                               |
| CMake        | 3.22.1                                                     |
| ONNX Runtime | 1.31.0, CPU, installed in `/usr/local`                     |
| nlohmann/json | 3.10.5 (`nlohmann-json3-dev`)                             |
| SSH server   | OpenSSH, port 22                                           |
| VS Code Server | 1.120.0, pre-installed for Remote-SSH                    |
| User         | `master`, password `111`, member of `sudo`                 |

## Build

```bash
docker build -t cpp-onnx-env .
```

- The image is always built for `linux/amd64`. On an ARM machine (for example an Apple Silicon Mac), Docker emulates x86, which is slower.
- The warning `FromPlatformFlagConstDisallowed` is expected. The platform is fixed in the Dockerfile on purpose.
- To use another ONNX Runtime version, pass `--build-arg ORT_VERSION=<version>`. The version needs an `onnxruntime-linux-x64-<version>.tgz` file on the [ONNX Runtime releases page](https://github.com/microsoft/onnxruntime/releases).
- To pre-install another VS Code Server version, pass `--build-arg VSCODE_VERSION=<version>`, for example `1.133.0`.
- To add more Ubuntu packages, add them to the **second** `apt-get install` step in the Dockerfile (the one with `nlohmann-json3-dev`). Changing the first step creates new SSH host keys.

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

**Shared folder (optional).** Add `-v <host folder>:/home/master/Document` to make a folder on your computer appear as `~/Document` in the container. Changes made on either side show up on the other. Without `-v`, `~/Document` is an empty folder inside the container.

```bash
# Windows (cmd or PowerShell)
docker run -d --name cpp-env -p 2222:22 -v "C:\Users\<you>\Documents:/home/master/Document" cpp-onnx-env

# Linux
docker run -d --name cpp-env -p 2222:22 -v ~/Documents:/home/master/Document cpp-onnx-env
```

`-v` can be combined with `-e SSH_PUBLIC_KEY=...`. On Linux, `master` has user ID 1000, so the host folder should belong to user ID 1000 for `master` to write to it. On Windows, `master` can write to it either way.

## Connect

```bash
ssh -p 2222 master@localhost
```

On another machine, replace `localhost` with that machine's IP address.

## Connect with VS Code (Remote-SSH)

Add an entry to your SSH config (`~/.ssh/config`, on Windows `C:\Users\<you>\.ssh\config`):

```
Host cpp-env
    HostName localhost
    Port 2222
    User master
```

In VS Code, run **Remote-SSH: Connect to Host...** and choose `cpp-env`.

The pre-installed server is used only if your local VS Code is exactly version 1.120.0 (check **Help → About**). With any other version, Remote-SSH downloads the matching server into the container, which needs internet access from the container. To avoid the download, rebuild the image with `--build-arg VSCODE_VERSION=<your version>`.

## Use ONNX Runtime

Headers are in `/usr/local/include/onnxruntime` and libraries in `/usr/local/lib`.

Both include styles work and point at the same files:

```cpp
#include <onnxruntime_cxx_api.h>                              // release-package style
#include <onnxruntime/core/session/onnxruntime_cxx_api.h>     // source-tree style
```

The release package ships its headers in one flat folder. The image also links them into `onnxruntime/core/session/`, the folder the ONNX Runtime source tree uses, so code written for either layout compiles unchanged.

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

**nlohmann/json** is header-only. With CMake:

```cmake
find_package(nlohmann_json 3.2.0 REQUIRED)
target_link_libraries(app PRIVATE nlohmann_json::nlohmann_json)
```

In code: `#include <nlohmann/json.hpp>`.

**Without CMake:**

```bash
g++ -std=c++17 main.cpp -I/usr/local/include/onnxruntime -lonnxruntime -o app
```

## Troubleshooting

**`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`**
The SSH host keys are created when the image is built. Containers from the same image share them, so recreating a container does not trigger this warning. Changing `ORT_VERSION` or `VSCODE_VERSION`, or adding packages to the second `apt-get install` step, keeps the keys. Rebuilding the image from scratch (for example with `--no-cache`) creates new keys. Remove the old entry, then connect again:

```bash
ssh-keygen -R "[localhost]:2222"
```

## Security

The password `111` is stored in the image, so anyone with the image knows it. If the SSH port can be reached from other machines, run the container with `SSH_PUBLIC_KEY` so that password login over SSH is turned off.
