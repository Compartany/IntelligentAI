@ECHO OFF

@REM 切换编码为 UTF-8
CHCP 65001

:PROMT
SET /P CONFIRM=确认发行吗？请确保本地更新已发布到远程仓库！(y/N) 
IF /I "%CONFIRM%" NEQ "y" GOTO END

SET /P version=<version.txt
ECHO Version: %version%

gh release create v%version% IntelligentAI.zip -t v%version%

ECHO GitHub Release 描述默认显示为提交信息。若该版本包含的更新不仅限于提交信息内容，请手动修改。
explorer https://github.com/Compartany/IntelligentAI/releases

:END
ECHO 完成