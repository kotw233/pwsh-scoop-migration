# lsd.ps1 - 目录美化命令别名（依赖 lsd）

function Invoke-LsdLong { lsd -l @args }
function Invoke-LsdAll { lsd -alFh @args }
function Invoke-LsdHuman { lsd -lFh @args }
function Invoke-LsdTree { lsd --tree @args }
function Invoke-LsdSize { lsd -l --size short @args }
function Invoke-LsdGit { lsd -l --git @args }
function Invoke-LsdTime { lsd -l --timesort @args }
function Invoke-LsdBig { lsd -l --sizesort @args }
