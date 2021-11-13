@ECHO OFF

@REM 切换编码为 UTF-8
CHCP 65001

SET zip=%ProgramFiles%/WinRAR/WinRAR
SET archive=archive
SET name=IntelligentAI
SET package=%name%.zip

lua scripts\init.lua >version.txt
SET /P version=<version.txt
ECHO Version: %version%

if EXIST %package% (
    DEL %package%
    ECHO Delete %package%
)

@REM -r 递归
"%zip%" a -ap%name% -r %package% img\
"%zip%" a -ap%name% -r %package% scripts\
"%zip%" a -ap%name% %package% "说明.txt"
"%zip%" a -ap%name% %package% "README.txt"
"%zip%" a -ap%name% %package% "version.txt"
ECHO Package %package%

COPY %package% %archive%\%version%.zip
ECHO Archive %version%.zip
