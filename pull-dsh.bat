@echo off
chcp 65001 >nul
REM ============================================================
REM  pull-dsh.bat —— 在 Windows 电脑上自动尝试多个镜像源，
REM  拉取 DSH 镜像并导出 dsh.tar，供 NAS「镜像→导入」使用。
REM
REM  用法（双击运行，或命令行）：
REM    pull-dsh.bat 你的GitHub用户名 [版本，默认 latest]
REM ============================================================

set USER=%~1
set VER=%~2
if "%USER%"=="" (
  echo 用法: pull-dsh.bat 你的GitHub用户名 [版本，默认 latest]
  echo 例如: pull-dsh.bat zhangsan latest
  pause
  exit /b 1
)
if "%VER%"=="" set VER=latest

where docker >nul 2>nul
if errorlevel 1 (
  echo.
  echo [错误] 这台电脑还没装 Docker。
  echo 请先安装 Docker Desktop（免费）: https://www.docker.com/products/docker-desktop/
  echo 装完并启动后，再双击本脚本。
  pause
  exit /b 1
)

set NAME=dsh-image

echo ============================================================
echo  开始尝试镜像源: ghcr.io 直连 + 3 个国内加速站
echo  目标: %USER%/%NAME%:%VER%
echo ============================================================

for %%S in (
  "ghcr.io/%USER%/%NAME%:%VER%"
  "ghcr.nju.edu.cn/%USER%/%NAME%:%VER%"
  "ghcr.dockerproxy.com/%USER%/%NAME%:%VER%"
  "ghcr.m.daocloud.io/%USER%/%NAME%:%VER%"
) do (
  echo.
  echo ==^> 尝试: docker pull %%~S
  docker pull %%~S
  if not errorlevel 1 (
    echo.
    echo ==^> 拉取成功！正在重命名并导出 dsh.tar ...
    docker tag %%~S dsh-local:%VER%
    docker save -o dsh.tar dsh-local:%VER%
    echo.
    echo ==^> 完成！dsh.tar 已生成在: %cd%\dsh.tar
    echo     下一步：上传到 NAS 文件管理 -^> Docker 应用 -^> 镜像 -^> 导入 -^> 选择 dsh.tar
    echo     （导入后镜像名为 dsh-local，创建容器时选它，命令框留空）
    pause
    exit /b 0
  )
  echo     %%~S 失败，换下一个源 ...
)

echo.
echo [失败] 全部镜像源都失败了。
echo 请检查: 1) 网络是否正常; 2) 镜像包是否已设为 Public（见 MIRRORS.md 第 3 节）
echo 或去 MIRRORS.md 第 1 节找最新可用加速站，加进本脚本的列表里重试。
pause
exit /b 1
